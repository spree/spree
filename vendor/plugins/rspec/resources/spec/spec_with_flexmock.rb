$:.push File.join(File.dirname(__FILE__), *%w[.. .. lib])
require "rubygems"
require 'spec'

Spec::Runner.configure do |config|
  config.mock_with :flexmock
end

describe "plugging in flexmock" do
  it "allows flexmock to be used" do
    target = Object.new
    flexmock(target).should_receive(:foo).once
    lambda {flexmock_verify}.should raise_error
  end
  
  it "does not include rspec mocks" do
    Spec.const_defined?(:Mocks).should be_false
  end
end