require File.dirname(__FILE__) + '/../spec_helper'

describe TaxRate do
  before(:each) do
    @tax_rate = TaxRate.new
  end

  it "should not be valid without a state and tax rate" do
    @tax_rate.should_not be_valid
  end
  
  it "should be valid with a state and tax rate" do
    @tax_rate.state = mock_model(State)
    @tax_rate.rate = 0.01
    @tax_rate.should be_valid
  end
  
  it "should not allow tax more then one tax rate for a given state" do
    state = mock_model State, {:name => "Foo", :id => 1}
    rate = TaxRate.new(:state => state, :rate => 0.1)
    TaxRate.stub!(:find).and_return(rate)
    @tax_rate.state = state
    @tax_rate.should_not be_valid
  end
  
end
