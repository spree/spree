require File.dirname(__FILE__) + '/../spec_helper'

describe Spree::SalesTaxCalculator do
  
  before :each do
    @product1 = mock_model(Product)
    @variant1 = mock_model(Variant, :product => @product1)
    @product2 = mock_model(Product)
    @variant2 = mock_model(Variant, :product => @product2)
    line_item1 = mock_model(LineItem, :variant => @variant1, :quantity => 2, :price => 50, :total => 100)
    line_item2 = mock_model(LineItem, :variant => @variant2, :quantity => 1, :price => 100, :total => 100)
    @line_items = [line_item1, line_item2]
    @order = mock_model(Order, :line_items => @line_items)
  end
  
  it "should calc zero tax if no rates provided" do
    Spree::SalesTaxCalculator.calculate_tax(@order, []).should == 0
  end
  
  it "should calc zero tax if none of the line items contains a taxable product" do
    tax_category = TaxCategory.create(:name => "foo")
    tax_rate = mock_model(TaxRate, :amount => 0.05, :category => tax_category)
    @product1.should_receive(:tax_category).and_return(nil)
    @product2.should_receive(:tax_category).and_return(nil)
    Spree::SalesTaxCalculator.calculate_tax(@order, [tax_rate]).should == 0
  end

  it "should calc tax only on the items that are taxable" do
    tax_category = TaxCategory.create(:name => "foo")
    tax_rate = TaxRate.new(:amount => 0.05, :tax_category => tax_category)
    @product1.should_receive(:tax_category).and_return(nil)
    @product2.should_receive(:tax_category).and_return(tax_category)
    Spree::SalesTaxCalculator.calculate_tax(@order, [tax_rate]).should == 5
  end
  
  it "should apply tax to the total of all taxable line items" do
    tax_category = TaxCategory.create(:name => "foo")
    tax_rate = TaxRate.new(:amount => 0.10, :tax_category => tax_category)
    @product1.stub!(:tax_category).and_return(tax_category)
    @product2.stub!(:tax_category).and_return(tax_category)
    Spree::SalesTaxCalculator.calculate_tax(@order, [tax_rate]).should == 20
  end
  
  it "should apply the correct tax rates based on tax category" do
    tax_category1 = TaxCategory.create(:name => "foo")
    tax_category2 = TaxCategory.create(:name => "bar")
    tax_rate1 = TaxRate.create(:amount => 0.10, :tax_category => tax_category1)
    tax_rate2 = TaxRate.create(:amount => 0.05, :tax_category => tax_category2)
    @product1.stub!(:tax_category).and_return(tax_category1)
    @product2.stub!(:tax_category).and_return(tax_category2)
    Spree::SalesTaxCalculator.calculate_tax(@order, [tax_rate1, tax_rate2]).should == 15
  end
end
