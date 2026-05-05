Pod::Spec.new do |s|
  s.name             = 'JustTrackSDK'
  s.version          = '7.1.0'
  s.summary          = 'justtrack is AppLike Group\'s next level attribution & UA automation platform - built by app publishers for app publishers.'

  s.description      = <<-DESC
The justtrack SDK provides you the ability to track attributions and user behavior of your app. Find out where your users are coming from, how they behave in your app, and where you can optimize your user acquisition.
                       DESC

  s.homepage         = 'https://docs.justtrack.io/sdk/overview'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors          = { 'justtrack' => 'https://justtrack.io/contact/' }
  s.source           = { :http => 'https://sdk.justtrack.io/pods/JustTrackSDK/JustTrackSDK-' + s.version.to_s + '.zip', :flatten => false }

  s.ios.deployment_target = '12.0'
  s.swift_versions        = '5.7', '5.8'
  s.requires_arc          = true

  if ENV["JUSTTRACK_DISTRIBUTION_MODE"] == "source" then
    s.source_files        = 'JustTrackSDK/**/*.{c,h,m,swift}'
    s.public_header_files = 'JustTrackSDK/JustTrackSDK.h', 'JustTrackSDK/Utils/JTInAppPurchaseTracker.h', 'JustTrackSDK/Utils/SignalHandlerComparator/SignalHandlerComparator.h'
  else
    s.source_files        = 'JustTrackSDK.xcframework/**/Headers/*.{c,h,m}'
    s.public_header_files = 'JustTrackSDK.xcframework/**/Headers/*.h'
    s.vendored_frameworks = 'JustTrackSDK.xcframework'
    s.preserve_paths      = 'JustTrackSDK.xcframework/*'
  end

  s.frameworks          = 'AdServices', 'AdSupport', 'AppTrackingTransparency', 'CoreTelephony', 'CryptoKit', 'Foundation', 'StoreKit', 'SystemConfiguration', 'UIKit'
end
