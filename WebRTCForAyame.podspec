#
# Be sure to run `pod lib lint WebRTCForAyame.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'WebRTCForAyame'
  s.version          = '0.1.5'
  s.summary          = 'WebRTCForAyame'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC

  Ayame在iOS上的使用
                       DESC

  s.homepage         = 'https://github.com/TaylorsZ/WebRTCForAyame.git'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'zhangs1992@126.com' => 'zhangs1992@126.com' }
  s.source           = { :git => 'https://github.com/TaylorsZ/WebRTCForAyame.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '12.1'

  s.source_files = 'WebRTCForAyame/Classes/**/*'
  s.swift_version='5.0'
  # s.resource_bundles = {
  #   'WebRTCForAyame' => ['WebRTCForAyame/Assets/*.png']
  # }

   s.public_header_files = 'Pod/Classes/**/*.swift'
  # s.frameworks = 'UIKit', 'MapKit'
   s.dependency 'ReachabilitySwift'
   s.dependency 'SocketRocket'
   s.dependency 'GoogleWebRTC'
   s.dependency 'DJIWidget'
end
