Pod::Spec.new do |s|
  s.name             = 'JustTrackSDKFirebaseAdapter'
  s.version          = '1.0.0'
  s.summary          = 'Firebase adapter for justtrack SDK.'

  s.description      = <<-DESC
The JustTrackSDKFirebaseAdapter allows you to integrate Firebase with the justtrack SDK.
                       DESC

  s.homepage         = 'https://docs.justtrack.io/sdk/integrations'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors          = { 'justtrack' => 'https://justtrack.io/contact/' }
  s.source           = { :http => 'https://sdk.justtrack.io/pods/JustTrackSDKFirebaseAdapter/JustTrackSDKFirebaseAdapter-' + s.version.to_s + '.zip', :flatten => false }

  s.ios.deployment_target = '12.0'
  s.swift_versions        = ['5.7', '5.8']
  s.requires_arc          = true

  if ENV["JUSTTRACK_DISTRIBUTION_MODE"] == "source" then
    s.source_files        = 'JustTrackSDKFirebaseAdapter/**/*.{c,h,m,swift}'
  else
    s.source_files        = 'JustTrackSDKFirebaseAdapter.xcframework/**/Headers/*.{c,h,m}'
    s.public_header_files = 'JustTrackSDKFirebaseAdapter.xcframework/**/Headers/*.h'
    s.vendored_frameworks = 'JustTrackSDKFirebaseAdapter.xcframework'
    s.preserve_paths      = 'JustTrackSDKFirebaseAdapter.xcframework/*'
  end

  s.frameworks       = ['Foundation']
  s.dependency         'JustTrackSDK'
end