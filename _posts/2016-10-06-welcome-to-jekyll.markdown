---
layout: post
title:  "实现webview登陆h5"
date:   2016-10-06 
categories: js h5
---



# Cookie 
  * http 协议中 Set-Cookie, Cookie 与cookies 相关
  * 客户端访问服务器，服务器响应头中如果包含Set-Cookie，会在客户端创建一个Cookie
  * 客户端访问URL时，只有cookie 的domain 和 path 与 请求的 URl 匹配时，cookie 才会包含在请求头中，发送给服务器
  * 例如：URL:https://www.baidu.com
  * 本地domain:www.baidu.com path:/   下的cookies  才会被包含在请求头中

# 使用cookie 实现登陆
  * 听起来有些不安全，目前项目中使用 oauth2 做的登陆，生成的 token 会被存储在redis,并作为Set-Cookie 发送给客户端，客户端使用唯一的token 进行身份验证。
  
# 安全考虑
  * 目前客户端拿到有效的 cookie 就可以实现登陆，那么大家会想盗取他人的cookie 实现登陆他人账户进行违规操作，那么问题来了，怎么盗取，跨网端的抓包不是那么容易的，并且拿到登陆token 后能做的操作也是有限的，如果想做进一步安全，可以考虑加https 安全系数倍增;
  
# app 实现跳转h5 自动登录
  * 既然了解了现阶段的登陆的原理，在app 的web view 中设置正确的 cookie 即可实现自动登录；

* ## ios app 实现webview登陆
<pre><code>
- (void)viewDidLoad {
    [super viewDidLoad];

    NSHTTPCookieStorage *myCookie = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [myCookie cookies]) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
        NSLog(@"%@", cookie);
    }
    
    NSDictionary *properties = [[NSMutableDictionary alloc] init];
    [properties setValue:@"20f38d6df7bf5f8f2dfaa154fce483e09e555316574eadd99f0b933586c25b73" forKey:NSHTTPCookieValue];
    [properties setValue:@"_v" forKey:NSHTTPCookieName];
    [properties setValue:@"htkg.uats.cc" forKey:NSHTTPCookieDomain];
    [properties setValue:@"/" forKey:NSHTTPCookiePath];
    [properties setValue:[NSDate dateWithTimeIntervalSinceNow:60*60] forKey:NSHTTPCookieExpires];
    NSHTTPCookie *cookie = [[NSHTTPCookie alloc] initWithProperties:properties];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:cookie];
    
    webView = [[UIWebView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.view addSubview: webView];
    
    NSURLRequest *request = [
                             NSURLRequest requestWithURL: [NSURL URLWithString: @"https://htkg.uats.cc"]
                             
                             cachePolicy: NSURLRequestReloadIgnoringCacheData timeoutInterval:15
                             ];
    
    //添加header
    NSMutableURLRequest *mutableRequest = [request mutableCopy];    //拷贝request
    [mutableRequest addValue:@"Bearer 20f38d6df7bf5f8f2dfaa154fce483e09e555316574eadd99f0b933586c25b73"
                forHTTPHeaderField:@"authorization"];

    request = [mutableRequest copy];
    
    NSLog(@"%@", request.allHTTPHeaderFields);  //打印出header验证
    
    [webView loadRequest: request];
}
</code></pre>

注：
 
start

   1. 在请求头中添加authorization,携带授权码即cookie,在node 端可以凭借其获取用户信息；
   2. 设置cookie 键名 _v, 键名 20f38d6df7bf5f8f2dfaa154fce483e09e555316574eadd99f0b933586c25b73；
   3. 设置cookie 时特别注意 domain 与 path 的设置；另header 中属性是不区分大小写的；

end
     
* ##android app 实现webview登陆
<pre><code>
CookieManager cookieManager = CookieManager.getInstance();
cookieManager.setCookie("ccat", "ccat="+cookieString+";Domain=htkg.uats.cc"+";Path=/");
</code></pre>
注：安卓代码有些混乱 就不贴全了，设置好后，访问domain 域下的网址就会携带本地 cookie 了；


#注:
  domain path 必须正确设置，否则cookie 不会被请求头携带，自然不会登陆；