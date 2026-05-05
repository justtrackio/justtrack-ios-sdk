Pod::Spec.new do |s|
  s.name             = 'JustTrackSDKUnityAdsAdapter'
  s.version          = '1.0.1'
  s.summary          = 'UnityAds adapter for justtrack SDK.'

  s.description      = <<-DESC
The JustTrackSDKUnityAdsAdapter allows you to integrate UnityAds with the justtrack SDK.
                       DESC

  s.homepage         = 'https://docs.justtrack.io/sdk/6.0.x/ios/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors          = { 'justtrack' => 'https://justtrack.io/contact/' }
  s.source           = { :http => 'https://sdk.justtrack.io/pods/JustTrackSDKUnityAdsAdapter/JustTrackSDKUnityAdsAdapter-' + s.version.to_s + '.zip', :flatten => false }

  s.ios.deployment_target = '12.0'
  s.swift_versions        = ['5.7', '5.8']
  s.requires_arc          = true

  if ENV["JUSTTRACK_DISTRIBUTION_MODE"] == "source" then
    s.source_files        = 'JustTrackSDKUnityAdsAdapter/**/*.{c,h,m,swift}'
  else
    s.source_files        = 'JustTrackSDKUnityAdsAdapter.xcframework/**/Headers/*.{c,h,m}'
    s.public_header_files = 'JustTrackSDKUnityAdsAdapter.xcframework/**/Headers/*.h'
    s.vendored_frameworks = 'JustTrackSDKUnityAdsAdapter.xcframework'
    s.preserve_paths      = 'JustTrackSDKUnityAdsAdapter.xcframework/*'
  end

  s.frameworks       = ['Foundation']
  s.dependency         'JustTrackSDK'
end