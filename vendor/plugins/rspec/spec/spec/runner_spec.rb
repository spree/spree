require File.dirname(__FILE__) + '/../spec_helper.rb'

module Spec
  describe Runner, ".configure" do
    it "should yield global configuration" do
      Spec::Runner.configure do |config|
        config.should equal(Spec::Runner.configuration)
      end
    end
  end
end