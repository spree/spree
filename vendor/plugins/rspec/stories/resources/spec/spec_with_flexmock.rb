$:.push File.join(File.dirname(__FILE__), *%w[.. .. .. lib])
require "rubygems"
require 'spec'

Spec::Runner.configure do |config|
  config.mock_with :flexmock
end

# This is to ensure that requiring spec/mocks/framework doesn't interfere w/ flexmock
require 'spec/mocks/framework'

describe "something" do
  it "should receive some message" do
    target = Object.new
    flexmock(target).should_receive(:foo).once
    lambda {flexmock_verify}.should raise_error
  end
end