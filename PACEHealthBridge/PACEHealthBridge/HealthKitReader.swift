import Foundation
import HealthKit

// The only data sent to the PACE web view. Never includes names, GPS, or identifiers
// beyond HealthKit's opaque workout UUID for avoiding duplicate records.
struct PACEWorkout: Codable {
    let id: String
    let type: String
    let start: String
    let end: String
    let durationMinutes: Double
    let activeKcal: Double?
}

struct PACEHeartRate: Codable {
    let ts: String
    let bpm: Double
}

struct PACEDailySteps: Codable {
    let date: String
    let count: Int
}

struct PACEHealthSnapshot: Codable {
    let schemaVersion: Int
    let source: String
    let generatedAt: String
    let workouts: [PACEWorkout]
    let heartRate: [PACEHeartRate]
    let steps: [PACEDailySteps]
}

enum HealthBridgeError: LocalizedError {
    case unavailable
    case accessNotGranted

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "这台设备不支持 Apple 健康数据。请在真实 iPhone 上使用。"
        case .accessNotGranted:
            return "未能完成健康数据授权。请到 iPhone 设置中检查 PACE Bridge 的健康权限。"
        }
    }
}

final class HealthKitReader {
    private let store = HKHealthStore()

    private let heartType = HKObjectType.quantityType(forIdentifier: .heartRate)!
    private let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
    private let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!

    private let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    func requestAccess() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthBridgeError.unavailable
        }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(), heartType, stepType
        ]
        // Completion means the permission dialog finished; it does NOT prove that
        // the user granted read access to every type (HealthKit protects this).
        let completed: Bool = try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
        if !completed { throw HealthBridgeError.accessNotGranted }
    }

    func readRecent(days: Int = 7) async throws -> PACEHealthSnapshot {
        let days = min(max(days, 1), 14)
        let now = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: now)!
        // Query workout metadata separately from heart-rate samples. Absence of
        // heart-rate samples is shown as missing data, never as 0 bpm.
        async let workoutsTask = samples(
            of: HKObjectType.workoutType(), from: start, to: now, limit: 100
        )
        async let heartTask = samples(
            of: heartType, from: start, to: now, limit: 12000
        )
        async let stepsTask = dailySteps(from: start, to: now)

        let workoutSamples = try await workoutsTask
        let heartSamples = try await heartTask
        let stepRows = try await stepsTask

        let workouts: [PACEWorkout] = workoutSamples.compactMap { object in
            guard let workout = object as? HKWorkout else { return nil }
            let kcal = workout.statistics(for: energyType)?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            return PACEWorkout(
                id: workout.uuid.uuidString,
                type: activityName(workout.workoutActivityType),
                start: iso.string(from: workout.startDate),
                end: iso.string(from: workout.endDate),
                durationMinutes: (workout.duration / 60.0 * 10).rounded() / 10,
                activeKcal: kcal
            )
        }

        let rates: [PACEHeartRate] = heartSamples.compactMap { object in
            guard let sample = object as? HKQuantitySample else { return nil }
            let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            guard bpm > 0, bpm < 260 else { return nil }
            return PACEHeartRate(ts: iso.string(from: sample.startDate), bpm: bpm)
        }

        return PACEHealthSnapshot(
            schemaVersion: 1,
            source: "iOS HealthKit (read-only)",
            generatedAt: iso.string(from: now),
            workouts: workouts,
            heartRate: rates,
            steps: stepRows
        )
    }

    private func samples(
        of type: HKSampleType,
        from start: Date,
        to end: Date,
        limit: Int
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: start, end: end, options: []
            )
            let sort = NSSortDescriptor(
                key: HKSampleSortIdentifierStartDate, ascending: false
            )
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: limit,
                sortDescriptors: [sort]
            ) { _, result, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: result ?? []) }
            }
            store.execute(query)
        }
    }

    private func dailySteps(from start: Date, to end: Date) async throws -> [PACEDailySteps] {
        try await withCheckedThrowingContinuation { continuation in
            let anchor = Calendar.current.startOfDay(for: start)
            let dateFormatter = DateFormatter()
            dateFormatter.calendar = Calendar.current
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let predicate = HKQuery.predicateForSamples(
                withStart: anchor, end: end, options: []
            )
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: anchor,
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var days: [PACEDailySteps] = []
                collection?.enumerateStatistics(from: anchor, to: end) { row, _ in
                    guard let sum = row.sumQuantity() else { return }
                    let count = max(0, Int(sum.doubleValue(for: .count()).rounded()))
                    days.append(PACEDailySteps(
                        date: dateFormatter.string(from: row.startDate),
                        count: count
                    ))
                }
                continuation.resume(returning: days)
            }
            store.execute(query)
        }
    }

    private func activityName(_ activity: HKWorkoutActivityType) -> String {
        switch activity {
        case .traditionalStrengthTraining: return "traditionalStrengthTraining"
        case .walking: return "walking"
        case .running: return "running"
        case .elliptical: return "elliptical"
        case .cycling: return "cycling"
        case .mixedCardio: return "mixedCardio"
        default: return "other"
        }
    }
}
