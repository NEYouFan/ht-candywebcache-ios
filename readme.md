#  CandyWebCache

CandyWebCache是移动端web资源的本地缓存的解决方案，能够拦截webview的请求，并优先使用本地缓存静态资源进行响应，以此来对webview加载页面性能进行优化。

特点：

* 协议层拦截请求，透明替换响应
* 静态资源版本控制及更新策略
* 资源防篡改策略
* 静态资源自动打包到应用，及首次安装解压处理


##  客户端集成CandyWebCache

###  一、使用CocoaPods安装CandyWebCache及依赖库

(1) 修改Podfile。CandyWebCache依赖于文件下载库HTFileDownloader和资源解压缩库ZipArchive。

```
pod 'CCCandyWebCache', :path => '../',:inhibit_warnings => true
pod 'ZipArchive', '~>1.3.0'
```

(2) 执行`pod install`或 `pod update`


###  二、修改和集成自动打包脚本

* 要求本地安装python

(1)从CCCandyWebCache源文件中找到`CC_build_script.py`文件，并拷贝到与应用工程文件同级目录。

(2)修改`CC_build_script.py`脚本文件相关配置信息

```
# connection info
WEBCACHE_SERVER = "10.165.124.46"
PORT = 8080

# appInfo
NATIVE_APP = "kaola"
NATIVE_VERSION = "1.0.0"
```

(3)添加打包脚本到工程

* Xcode打包
	* 在Xcode中选中工程文件 -> Build Phases
	* 菜单栏Editor -> Add Build Phase -> Add Run Script Build Phase，在Build Phases可以看到新添加的Run Script，双击重命名为CandyWebCache Script
	* 在Shell栏输入：` /usr/bin/python CC_build_script.py -b ${BUILT_PRODUCTS_DIR} -p ${FULL_PRODUCT_NAME}`，其中BUILT_PRODUCTS_DIR是build app所在路径，FULL_PRODUCT_NAME是app全名
	* 如果日常debug想关闭每次build执行脚本，可以将`Run script only when installing`设置为勾选状态，等到真正进行product archive时，才会执行脚本

* 脚本打包
	* 在打包脚本中添加`CC_build_script.py`的执行，注意传入正确的参数

脚本执行后，会向服务器请求线上最新资源，根据服务器返回结果，将线上最新的资源包下载并打包到app安装包中。


###  三、CandyWebCache配置

(1)导入头文件

```
#import "CCCandyWebCache.h"
```

(2)配置CandyWebCache

可以在AppDelegate.m的application:didFinishLaunchingWithOptions:方法中配置，也可以在其他合适的地方进行配置。

**注意：设置配置信息接口[CCCandyWebCache setDefaultConfiguration:config]必须在首次调用[CCCandyWebCache defaultWebCache]之前进行调用，否则将忽略用户设置的配置信息而采用默认配置信息。**

```
    CCCandyWebCacheConfig* config = [CCCandyWebCacheConfig new];
    config.serverAddress = @"10.165.124.46:8080";
    config.appName = @"kaoLa";
    config.appVersion = @"1.0.1";
    config.blackListResourceTypes = @[@"html"];
    [CCCandyWebCache setDefaultConfiguration:config];

```

(3)配置CCCacheManager[可选]

```
	CCCandyWebCache* cacheManager = [CCCandyWebCache defaultWebCache].cacheManager;
	cacheManager.cocurrentDownloadCount = 3;
	cacheManager.memCacheSize = 10 * 1024 * 1024;

```

###  四、CandyWebCache的使用

(1)可以根据需求在合适的时间，如应用启动、前后台切换等，调用接口进行版本检测和更新。

```
[[CCCandyWebCache defaultWebCache] checkAndUpdateResource];
```

(2)也可以在配置信息CCCandyWebCacheConfig中设置pullInterval进行定时周期性资源检测和更新。

```
config.pullInterval = 10 * 60; //十分钟

```

(3)可以添加对象作为资源更新的监听器，监听器会收到资源更新的相关事件通知，但要在合适的时间，移除监听器，防止内存泄露。

```
- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[[CCCandyWebCache defaultWebCache] addObserver:self];
	...
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
   [[CCCandyWebCache defaultWebCache] removeObserver:self];
   ...
}

```

###  五、全局开关

* 缓存功能开关，关闭将禁用CandyWebCache

```
	[CCCandyWebCache defaultWebCache].enable = NO;
```

* 增量更新功能开关，关闭将只做全量更新

```
	[CCCandyWebCache defaultWebCache].diffEnable = YES;
```

##  调试

(1)启用CandyWebCache日志

```
[CCCandyWebCache setLogEnable:YES];
```

(2)设置日志级别

```
[CCCandyWebCache setLogLevel:CCLoggerLevelDebug];
```

## 测试

为了方便测试，我们提供了demo服务器来配合集成CandyWebCache之后，进行测试。
[demo服务器](https://github.com/NEYouFan/ht-candywebcache-demo-server)

## CandyWebCache客户端SDK对服务器的要求

提供给客户端SDK的接口：

* 版本检测接口，返回信息包括
	* 请求的webapp对应的增量包和全量包信息：版本号、下载地址、md5、url、domains
	* 请求中不包含的webapp则返回全量包信息：版本号、下载地址、md5、url、domains

提供给应用服务器的接口：

* 更新全量包
	* 根据全量包和历史N(N可配置)个版本的包进行diff包计算
	* 计算各个资源包的md5，并加密md5值
	* 上传增量包和全量包到文件服务，并记录各个包的md5、资源url、版本号信息、domains

服务端功能要求：

* 计算资源包diff包（使用bsdiff）
* 上传资源到文件服务器
* 资源md5计算与加密（加密算法:DES + base64，客户端对称加密秘钥目前是埋在客户端代码中）
* webapp domains的配置

## CandyWebCache客户端SDK对打包方式的要求

* 打包资源包目录路径要跟url能够对应，如 `http://m.kaola.com/public/r/js/core_57384232.js` ，资源的存放路径需要是 `public/r/js/core_57384232.js` 或者 `r/js/core_57384232.js`。
* 资源缓存不支持带“?”的url，如果有版本号信息需要打到文件名中。对于为了解决缓存问题所采用的后缀形式url，如 `http://m.kaola.com/public/r/js/core.js?v=57384232` ,需要调整打包方式，采用文件名来区分版本号

##  系统要求

该项目最低支持`iOS 7.0`和`Xcode 7.0`

##  许可证

CandyWebCache使用MIT许可证，详情见[LICENSE](./LICENSE.txt)文件。
