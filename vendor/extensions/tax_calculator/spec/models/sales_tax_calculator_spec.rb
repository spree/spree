require File.dirname(__FILE__) + '/../spec_helper'

describe Spree::SalesTaxCalculator do
  
  before :each do
    @line_items = []
    @order = mock_model(Order, :line_items => @line_items)
    @tax_rate = mock_model(TaxRate, :amount => 0.05)
    @product1 = mock_model(Product)
    @variant1 = mock_model(Variant, :product => @product1)
    @product2 = mock_model(Product)
    @variant2 = mock_model(Variant, :product => @product2)
    @clothing = mock_model(Property, :name => "Clothing")
  end
  
  it "should calc zero tax if no rates provided" do
    Spree::SalesTaxCalculator.calculate_tax(@order, []).should == 0
  end
  
  it "should calc zero tax if none of the line items contains a taxable product" 
=begin
  do 
    @product1.should_receive(:property_values).with(:tax_category).and_return([])
    @line_items << mock_model(LineItem, :variant => @variant1) 
    @product2.should_receive(:property_values).with(:tax_category).and_return([])
    @line_items << mock_model(LineItem, :variant => @variant1)
    Spree::SalesTaxCalculator.calculate_tax(@order, [@tax_rate])
  end
=end  
  it "should calc tax only on the items that are taxable" 
=begin do
    @product1.should_receive(:property_values).with(:tax_category).and_return([@clothing])
    @line_items << mock_model(LineItem, :variant => @variant1) 
    @product2.should_receive(:property_values).with(:tax_category).and_return([])
    @line_items << mock_model(LineItem, :variant => @variant1)
    Spree::SalesTaxCalculator.calculate_tax(@order, [@tax_rate])
  end
=end
end
