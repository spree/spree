require File.dirname(__FILE__) + '/spec_helper'

# Run spec w/ -fs to see the output of this file

describe "Failing examples with no descriptions" do
  
  # description is auto-generated as "should equal(5)" based on the last #should
  it do
    3.should equal(2)
    5.should equal(5)
  end
  
  it { 3.should be > 5 }
  
  it { ["a"].should include("b") }
  
  it { [1,2,3].should_not respond_to(:size) }
  
end
