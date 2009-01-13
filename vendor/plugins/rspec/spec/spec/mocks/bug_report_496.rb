require File.dirname(__FILE__) + '/../../spec_helper.rb'

module BugReport496
  class BaseClass
  end

  class SubClass < BaseClass
  end

  describe "a message expectation on a base class object" do
    it "should correctly pick up message sent to it subclass" do
      pending("fix for http://rspec.lighthouseapp.com/projects/5645/tickets/496") do
        BaseClass.should_receive(:new).once
        SubClass.new
      end
    end
  end
end

