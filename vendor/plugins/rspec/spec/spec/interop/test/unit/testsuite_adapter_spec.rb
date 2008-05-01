require File.dirname(__FILE__) + '/test_unit_spec_helper'

describe "TestSuiteAdapter" do
  include TestUnitSpecHelper
  it "should pass" do
    dir = File.dirname(__FILE__)
    run_script "#{dir}/resources/testsuite_adapter_spec_with_test_unit.rb"
  end
end