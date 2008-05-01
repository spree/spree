dir = File.dirname(__FILE__)
$LOAD_PATH.unshift(File.expand_path("#{dir}/../../../../../../rspec/lib"))
require 'spec'
$LOAD_PATH.unshift(File.expand_path("#{dir}/../../"))
require "#{dir}/../../life"
require File.join(File.dirname(__FILE__), *%w[steps])