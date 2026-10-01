Pod::Spec.new do |s|
  s.name             = 'JustTrackSDKAppLovinAdapter'
  s.version          = '1.0.2'
  s.summary          = 'AppLovin adapter for justtrack SDK.'

  s.description      = <<-DESC
The JustTrackSDKAppLovinAdapter allows you to integrate AppLovin with the justtrack SDK.
                       DESC

  s.homepage         = 'https://docs.justtrack.io/sdk/integrations'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.authors          = { 'justtrack' => 'https://justtrack.io/contact/' }
  s.source           = { :http => 'https://sdk.justtrack.io/pods/JustTrackSDKAppLovinAdapter/JustTrackSDKAppLovinAdapter-' + s.version.to_s + '.zip', :flatten => false }

  s.ios.deployment_target = '12.0'
  s.swift_versions        = ['5.7', '5.8']
  s.requires_arc          = true

  if ENV["JUSTTRACK_DISTRIBUTION_MODE"] == "source" then
    s.source_files        = 'JustTrackSDKAppLovinAdapter/**/*.{c,h,m,swift}'
  else
    s.source_files        = 'JustTrackSDKAppLovinAdapter.xcframework/**/Headers/*.{c,h,m}'
    s.public_header_files = 'JustTrackSDKAppLovinAdapter.xcframework/**/Headers/*.h'
    s.vendored_frameworks = 'JustTrackSDKAppLovinAdapter.xcframework'
    s.preserve_paths      = 'JustTrackSDKAppLovinAdapter.xcframework/*'
  end

  s.frameworks       = ['Foundation']
  s.dependency         'JustTrackSDK'
end