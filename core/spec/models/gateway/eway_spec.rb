require 'spec_helper'

describe Gateway::Eway do
  let (:gateway) { Gateway::Eway.new }

  describe "options" do
    it "should include :test => true in  when :test_mode is true" do
      gateway.prefers_test_mode = true
      gateway.options[:test].should == true
    end

    it "should not include :test when test_mode is false" do
      gateway.prefers_test_mode = false
      gateway.options[:test].should be_nil
    end
  end
end
