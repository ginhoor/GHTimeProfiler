#
# Be sure to run `pod lib lint GHTimeProfiler.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'GHTimeProfiler'
  s.version          = '1.3.1'
  s.summary          = 'A short description of GHTimeProfiler.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/ginhoor/GHTimeProfiler'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Ginhoor' => 'ginhoor@gmail.com' }
  s.source           = { :git => 'git@github.com:ginhoor/GHTimeProfiler.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |ss|
    ss.source_files = 'GHTimeProfiler/Classes/Core/**/*'

  end

  s.subspec 'Observer' do |ss|
    ss.source_files = 'GHTimeProfiler/Classes/Observer/**/*'
    ss.dependency 'GHTimeProfiler/Core'
  end

  s.subspec 'TimeProfiler' do |ss|
    ss.source_files = 'GHTimeProfiler/Classes/TimeProfiler/**/*'

    ss.dependency 'GHTimeProfiler/Core'
    ss.dependency 'FMDB'
  end


end
