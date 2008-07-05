require File.dirname(__FILE__) + '/../spec_helper'

describe Spree::VatCalculator do

  before :each do
    @order = mock_model(Order)
  end
  
  it "should calc zero tax if no rates provided" do
    Spree::VatCalculator.calculate_tax(@order, []).should == 0
  end
  
  it "should calc zero tax if none of the line items contains a taxable product"
  it "should calc tax only on the items that are taxable"
end
