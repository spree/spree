require File.dirname(__FILE__) + '/spec_helper'

# Run spec w/ -fs to see the output of this file

describe "Examples with no descriptions" do
  
  # description is auto-generated as "should equal(5)" based on the last #should
  specify do
    3.should equal(3)
    5.should equal(5)
  end
  
  specify { 3.should be < 5 }
  
  specify { ["a"].should include("a") }
  
  specify { [1,2,3].should respond_to(:size) }
  
end

describe "the number 1" do
  subject { 1 }
  it { should == 1 }
  it { should be < 2}
end
