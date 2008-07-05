require File.dirname(__FILE__) + '/../spec_helper'

describe TaxRate do
  before(:each) do
    @tax_rate = TaxRate.new(:tax_type => TaxRate::TaxType::SALES_TAX)
  end

  it "should not be valid without a zone and tax rate" do
    @tax_rate.should_not be_valid
  end
  
  it "should be valid with a zone and tax rate" do
    @tax_rate.zone = mock_model(Zone)
    @tax_rate.rate = 0.01
    @tax_rate.should be_valid
  end
=begin  
  it "should not allow tax more then one tax rate for a given state" do
    state = mock_model State, {:name => "Foo", :id => 1}
    rate = TaxRate.new(:state => state, :rate => 0.1)
    TaxRate.stub!(:find).and_return(rate)
    @tax_rate.state = state
    @tax_rate.should_not be_valid
  end
=end  
end
