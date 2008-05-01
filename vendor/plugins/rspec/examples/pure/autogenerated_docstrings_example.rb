require File.dirname(__FILE__) + '/spec_helper'

# Run spec w/ -fs to see the output of this file

describe "Examples with no descriptions" do
  
  # description is auto-generated as "should equal(5)" based on the last #should
  it do
    3.should equal(3)
    5.should equal(5)
  end
  
  it { 3.should be < 5 }
  
  it { ["a"].should include("a") }
  
  it { [1,2,3].should respond_to(:size) }
  
end
