require File.dirname(__FILE__) + '/../spec_helper'

describe "A sample spec", :type => :model do
  fixtures :animals
  it "should pass" do
    animals(:pig).name.should == "Piggy"
  end
end