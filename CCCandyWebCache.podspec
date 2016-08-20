# coding: utf-8
#
#  Be sure to run `pod spec lint HTUI.podspec' to ensure this is a
#  valid spec and to remove all comments including this before submitting the spec.
#
#  To learn more about Podspec attributes see http://docs.cocoapods.org/specification.html
#  To see working Podspecs in the CocoaPods repo see https://github.com/CocoaPods/Specs/
#

Pod::Spec.new do |s|


  s.name         = "CCCandyWebCache"
  s.version      = "0.0.1"
  s.summary      = "iOS资源缓存解决方案"

  s.description  = <<-DESC
                   iOS资源缓存解决方案.
                   DESC

  s.homepage     = "https://g.hz.netease.com/web-cache/CCCandyWebCache-ios"

  s.license      = "MIT"

  s.author       = { "hzzhangjw" => "hzzhangjw@corp.netease.com" }

  s.source       = { :git => 'https://g.hz.netease.com/web-cache/CCCandyWebCache-ios.git' }

  s.platform     = :ios, "7.0"

  s.ios.deployment_target = "7.0"

  s.library = 'sqlite3'

  s.source_files  = "src/CCCandyWebCache/*.{h,m}","src/CCCandyWebCache/CacheManager/*.{h,m}","src/CCCandyWebCache/WebViewProtocol/*.{h,m}","src/CCCandyWebCache/Utils/*.{h,m}","src/CCCandyWebCache/CC_build_script_sample.py","src/bsdiff/bsdiff/*.{h,c}","src/bsdiff/bzip2/*.{h,c}","src/bsdiff/bzip2/*.{h,c}","src/HTFileDownloader/*.{h,m}","src/VersionChecker/*.{h,m}"
  
  s.requires_arc = true
end
