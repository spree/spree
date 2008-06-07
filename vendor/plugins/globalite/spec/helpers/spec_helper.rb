begin
  require 'rubygems'
  require 'spec'
rescue LoadError
  puts "==> The test/spec library (gem) is required to run the Globalite tests."
  exit
end

$:.unshift File.dirname(__FILE__) + '/../../lib'
ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../../../../../config/environment")
require 'globalite'

# add and Load the spec localization files
Globalite.add_localization_source(File.dirname(__FILE__) + '/../lang/ui')
Globalite.load_localization!