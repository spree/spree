# Load the plugin testing framework
$:.unshift("#{File.dirname(__FILE__)}/../../plugin_test_helper/lib")
require 'rubygems'
require 'plugin_test_helper'

# Run the migrations
ActiveRecord::Migrator.migrate("#{Rails.root}/db/migrate")

# Mixin the factory helper
require File.expand_path("#{File.dirname(__FILE__)}/factory")
class Test::Unit::TestCase #:nodoc:
  include Factory
end
