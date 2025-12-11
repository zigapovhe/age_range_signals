#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint age_range_signals.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'age_range_signals'
  s.version          = '0.3.0'
  s.summary          = 'Flutter plugin for age verification.'
  s.description      = <<-DESC
Flutter plugin for age verification supporting Google Play Age Signals API (Android) and Apple's DeclaredAgeRange API (iOS 26+).
                       DESC
  s.homepage         = 'https://github.com/zigapovhe/age_range_signals'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'zigapovhe' => 'ziga@povhe.si' }
  s.source           = { :path => '.' }
  s.source_files = 'age_range_signals/Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'

  s.resource_bundles = {'age_range_signals_privacy' => ['age_range_signals/Resources/PrivacyInfo.xcprivacy']}
end
