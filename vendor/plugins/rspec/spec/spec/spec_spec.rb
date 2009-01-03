require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Spec::Runner, "#exit?" do
  describe "when ::Test is absent during loading but present when running exit?" do
    # believe it or not, this can happen when ActiveSupport is loaded after RSpec is, 
    # since it loads active_support/core_ext/test/unit/assertions.rb which defines
    # Test::Unit but doesn't actually load test/unit

    before(:each) do
      Object.const_set(:Test, Module.new)
    end
    
    it "does not attempt to access the non-loaded test/unit library" do
      lambda { Spec::Runner.exit? }.should_not raise_error
    end
    
    after(:each) do
      Object.send(:remove_const, :Test)
    end
  end
end
