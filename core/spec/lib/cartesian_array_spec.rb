require 'spec_helper'

describe 'Spree::Core::CartesianArray' do

  it "calculates cartesian product" do
    Spree::Core::CartesianArray.new([0,1], [0,1]).product.should == [[0, 0], [0, 1], [1, 0], [1, 1]]
  end
    
  it "calculates cartesian product with an argument" do
    Spree::Core::CartesianArray.new([0,1]).product([0,1]).should == [[0, 0], [0, 1], [1, 0], [1, 1]]
  end
  
  it "calculates cartesian product with string values" do
    Spree::Core::CartesianArray.new([0,1], %w(s m)).product.should == [[0, "s"], [0, "m"], [1, "s"], [1, "m"]]
  end
  
  it "calculates cartesian product with arrays with uneven numbers" do
    Spree::Core::CartesianArray.new([0,1], %w(s m l)).product.should == [[0, "s"], [0, "m"], [0, "l"], [1, "s"], [1, "m"], [1, "l"]]
  end
  
  it "calculates cartesian product with more than two arrays" do
    Spree::Core::CartesianArray.new([0,1], %w(s m l), %w(a b)).product.should == [
      [0, "s", "a"],
      [0, "s", "b"],
      [0, "m", "a"],
      [0, "m", "b"],
      [0, "l", "a"],
      [0, "l", "b"],
      [1, "s", "a"],
      [1, "s", "b"],
      [1, "m", "a"],
      [1, "m", "b"],
      [1, "l", "a"],
      [1, "l", "b"]
    ]
  end

end
