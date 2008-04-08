dir = File.dirname(__FILE__)
$LOAD_PATH.unshift File.expand_path("#{dir}/../lib")
require File.expand_path("#{dir}/../../../../spec/spec_helper")

require 'spec/rails/story_adapter'