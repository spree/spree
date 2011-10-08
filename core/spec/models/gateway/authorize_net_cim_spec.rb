require 'spec_helper'

describe Spree::Gateway::AuthorizeNetCim do
  let (:gateway) { Spree::Gateway::AuthorizeNetCim.new }

  describe "options" do
    it "should include :test => true when :test_mode is true" do
      gateway.prefers_test_mode = true
      gateway.options[:test].should == true
    end

    it "should not include :test when :test_mode is false" do
      gateway.prefers_test_mode = false
      gateway.options[:test].should be_nil
    end
  end
end

