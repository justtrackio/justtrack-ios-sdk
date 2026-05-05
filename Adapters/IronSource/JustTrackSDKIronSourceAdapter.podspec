Pod::Spec.new do |s|
  s.name             = 'JustTrackSDKIronSourceAdapter'
  s.version          = '1.0.0'
  s.summary          = 'IronSource adapter for justtrack SDK.'

  s.description      = <<-DESC
The JustTrackSDKIronSourceAdapter allows you to integrate IronSource with the justtrack SDK.
                       DESC

  s.homepage         = 'https://docs.justtrack.io/sdk/6.0.x/ios/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors          = { 'justtrack' => 'https://justtrack.io/contact/' }
  s.source           = { :http => 'https://sdk.justtrack.io/pods/JustTrackSDKIronSourceAdapter/JustTrackSDKIronSourceAdapter-' + s.version.to_s + '.zip', :flatten => false }

  s.ios.deployment_target = '12.0'
  s.swift_versions        = ['5.7', '5.8']
  s.requires_arc          = true

  if ENV["JUSTTRACK_DISTRIBUTION_MODE"] == "source" then
    s.source_files        = 'JustTrackSDKIronSourceAdapter/**/*.{c,h,m,swift}'
  else
    s.source_files        = 'JustTrackSDKIronSourceAdapter.xcframework/**/Headers/*.{c,h,m}'
    s.public_header_files = 'JustTrackSDKIronSourceAdapter.xcframework/**/Headers/*.h'
    s.vendored_frameworks = 'JustTrackSDKIronSourceAdapter.xcframework'
    s.preserve_paths      = 'JustTrackSDKIronSourceAdapter.xcframework/*'
  end

  s.frameworks       = ['Foundation']
  s.dependency         'JustTrackSDK'
end