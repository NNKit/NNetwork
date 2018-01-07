#
# Be sure to run `pod lib lint NNetwork.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'NNetwork'
  s.version          = '0.0.1'
  s.summary          = 'A short description of NNetwork.'
  s.homepage         = 'https://github.com/NNKit/NNetwork'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ws00801526' => '3057600441@qq.com' }
  s.source           = { :git => 'https://github.com/NNKit/NNetwork.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files = 'NNetwork/Classes/**/*'
  s.public_header_files = 'NNetwork/Classes/**/*.h'
  s.private_header_files = 'NNetwork/Classes/Core/NNetworkPrivate.h'
  s.dependency 'NNCore'
  s.dependency 'YYCache'
  s.dependency 'AFNetworking', '~> 3.0'
end
