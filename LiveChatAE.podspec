Pod::Spec.new do |s|
  s.name             = 'LiveChatAE'
  s.version          = '1.0.0'
  s.summary          = 'livechat.ae chat for iPhone and iPad apps.'
  s.description      = 'The livechat.ae chat in your app: visitor details, events, unread count, chat button and push notifications through webhooks.'
  s.homepage         = 'https://github.com/gatehillsreg/livechat-ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'livechat.ae' => 'support@livechat.ae' }
  s.source           = { :git => 'https://github.com/gatehillsreg/livechat-ios-sdk.git', :tag => s.version.to_s }
  s.ios.deployment_target = '15.0'
  s.swift_versions   = ['5.9']
  s.source_files     = 'Sources/LiveChatAE/**/*.swift'
  s.frameworks       = 'UIKit', 'WebKit', 'SafariServices'
end
