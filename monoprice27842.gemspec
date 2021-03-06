# frozen_string_literal: true

require_relative 'lib/monoprice27842/version'

Gem::Specification.new do |s|
  s.name = 'monoprice27842'
  s.version = Monoprice27842::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ['Cody Cutrer']
  s.email = "cody@cutrer.com'"
  s.homepage = 'https://github.com/ccutrer/monoprice27842'
  s.summary = 'Library for communication with Monoprice 27842 HDMI Matrix'
  s.license = 'MIT'
  s.required_ruby_version = Gem::Requirement.new('~> 2.5')

  s.executables = ['monoprice27842_mqtt_bridge']
  s.files = Dir['{bin,lib}/**/*']

  s.add_dependency 'ccutrer-serialport', '~> 1.0'
  s.add_dependency 'homie-mqtt', '~> 1.2'
  s.add_dependency 'net-telnet-rfc2217', '~> 1.0'

  s.add_development_dependency 'byebug', '~> 9.0'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rubocop', '~> 1.14'
end
