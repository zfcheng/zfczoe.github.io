---
layout: post
title:  "form 实现文件上传"
date:   2016-10-10 
categories: js uploadFile
---



#form 实现文件上传


* 使用form 上传文件时需要设置表单的MIME编码 `enctype="multipart/form-data"`, 使表单以二进制的上传至服务器，默认情况，这个编码格式是application/x-www-form-urlencoded，不能用于文件上传；

* form 上传的另一个问题是页面的刷新问题，可以使用`iframe`解决，设置提交文件的`form`表单的的`target`属性为`iframe`的`id`，这样在触发表单事件时会刷新到当前的`iframe`，造成一个`ajax`的假象。


简单的使用 `form` 提交文件代码

```
html 代码：

<form  action="https://htkg.uats.cc/api/v2/loan/uploadTemplate" method="POST" name="xx" id="xx" enctype="multipart/form-data">
        <input type="hidden" name='loanRequestId' value="8306E53C-1E25-4F83-85EA-A4790FB4ABAD">
        <input type="hidden" name='name' value="55">
        <input type="file" name='file' id='_v'>
        <!-- file id 建议写好   不完全测试 chrome 版本 42.0.2311.152 (64-bit) 不带 id  文件传不上去
            safari 就可以不带

            在上传文件时，<form>标签必须加上enctype="multipart/form-data"，否则浏览器无法将文件内容上传到服务端。
            表单中enctype="multipart/form-data"的意思，是设置表单的MIME编码。
            enctype="multipart/form-data"是上传二进制数据; 
        -->
        <input type="submit" value="submit">
</form>

```
这样实现了一个文件上传操作，缺点是页面会跳转刷新，并且文件上传后不知道是否成功也获取不到返回的数据。


#借助 iframe 实现文件上传
动态创建 `form iframe` 

```
createForm: function(id, fileId, data){   
        var formId = 'form_' + id;
        $.globalData.formId = formId;
        var form = $('<form  action="" method="POST" name="' + formId + '" id="' + formId + '" enctype="multipart/form-data"></form>');
        var fileElement = $('#' + fileId);
        var newFileElement = fileElement.clone();
        fileElement.before(newFileElement);
        fileElement.appendTo(form);
        if (data) { 
            for (var i in data) { 
                $('<input type="hidden" name="' + i + '" value="' + data[i] + '" />').appendTo(form);
            } 
        }
        $(form).css('position', 'absolute');
        $(form).css('top', '-2000px');
        $(form).css('left', '-2000px');
        $(form).appendTo('body');
        return form;
    }
    
createIframe: function(id, uri){
        var iFrameId = 'iFrameId_' + id;
        $.globalData.iFrameId = iFrameId;
        if(window.ActiveXObject) {
            var elem = document.createElement('<iframe id="' + iFrameId + '" name="' + iFrameId + '" />');
            if(typeof uri== 'boolean'){
                elem.src = 'javascript:false';
            }
            else if(typeof uri== 'string'){
                elem.src = uri;
            }
        }
        else {
            var elem = document.createElement('iframe');
            elem.id = iFrameId;
            elem.name = iFrameId;
        }
        elem.style.position = 'absolute';
        elem.style.top = '-2000px';
        elem.style.left = '-2000px';
        document.body.appendChild(elem);
        return elem;
    },
    
```


将 `form target` 指向 `iframe` 提交后，接口返回的信息会被嵌入`iframe`, 将内容解析可以得到接口的返回数据

```
uploadHttpData: function( r, type ) {
        if(!type) {  type = 'json'; }
        if ( type == "json" ){
            var data = r.responseText;
            var reg = new RegExp("<pre.*?>(.*?)</pre>","i");
            var arr = reg.exec(data);
            var data = (arr) ? arr[1] : "";
            eval( "data = " + data );
        }
        return data;
    }
    
```

具体实现代码 <a src="https://github.com/zfczoe/uploadFile">https://github.com/zfczoe/uploadFile</a>




