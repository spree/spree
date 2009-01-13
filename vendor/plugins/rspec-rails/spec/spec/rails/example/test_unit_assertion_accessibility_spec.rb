require File.dirname(__FILE__) + '/../../../spec_helper'

describe "assert_equal", :shared => true do
  it "like assert_equal" do
    assert_equal 1, 1
    lambda {
      assert_equal 1, 2
    }.should raise_error(Test::Unit::AssertionFailedError)
  end
end

describe "A model spec should be able to access 'test/unit' assertions", :type => :model do
  it_should_behave_like "assert_equal"
end

describe "A view spec should be able to access 'test/unit' assertions", :type => :view do
  it_should_behave_like "assert_equal"
end

describe "A helper spec should be able to access 'test/unit' assertions", :type => :helper do
  it_should_behave_like "assert_equal"
end

describe "A controller spec with integrated views should be able to access 'test/unit' assertions", :type => :controller do
  controller_name :controller_spec
  integrate_views
  it_should_behave_like "assert_equal"
end

describe "A controller spec should be able to access 'test/unit' assertions", :type => :controller do
  controller_name :controller_spec
  it_should_behave_like "assert_equal"
end
