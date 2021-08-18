# coding: utf-8
Pod::Spec.new do |s|
    s.name                      = 'DatadogSDKTesting'
    s.version                   = '0.9.3'
    s.summary                   = 'DatadogSDKTesting Swift'
    s.description               = <<-DESC
                                    DatadogSDKTesting SDK
                                    DESC
    s.homepage                  = "https://github.com/dcacenabes/dd-sdk-swift-testing"
    s.source                    = { :git => 'https://github.com/dcacenabes/dd-sdk-swift-testing.git', :tag => '0.9.3' }
    s.author                    = 'DataDog'
    s.license                   = { :type => 'Apache 2.0'}
    s.vendored_frameworks = 'DatadogSDKTesting.xcframework'
    
    s.ios.deployment_target     = '11.0'
    end