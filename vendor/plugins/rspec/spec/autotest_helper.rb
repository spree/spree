require "rubygems"
require 'autotest'
dir = File.dirname(__FILE__)
require "#{dir}/spec_helper"
require File.expand_path("#{dir}/../lib/autotest/rspec")
require "#{dir}/autotest_matchers"
