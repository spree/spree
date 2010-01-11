$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'stump/version'
require 'stump/metaid'
require 'stump/core_ext/test_case'

require 'stump/stub'
require 'stump/mocks'
require 'stump/mock'
require 'stump/proxy'