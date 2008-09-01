require File.dirname(__FILE__) + '/../spec_helper'

describe Spree::TaxCalculator do
  
  before :each do
    @address = mock_model(Address)
    @order = mock_model(Order)
    @order.should_receive(:address).and_return(@address)
    @order.extend Spree::TaxCalculator
  end
  
  it "should not apply tax if there is no tax zone" do
    @order.calculate_tax.should == 0
  end
  
  describe "with a ship address matching a zone" do
    
    before :each do
      @zone = mock_model(Zone)
      Zone.stub!(:match).with(@address).and_return([@zone])
      @tax_category = mock_model(TaxCategory)
      @vat_rate = mock_model(TaxRate, :tax_type => TaxRate::TaxType::VAT, :tax_category => @tax_category)
      @sales_rate = mock_model(TaxRate, :tax_type => TaxRate::TaxType::SALES_TAX, :tax_category => @tax_category)
    end
    
    it "should calc zero tax if there is no tax rate matching the same zone" do
      TaxRate.should_receive(:by_zone).with(@zone).and_return([])
      @order.calculate_tax.should == 0
    end
    
    describe "with tax rates of two different types" do
      before :each do 
        TaxRate.should_receive(:by_zone).with(@zone).and_return([@sales_rate, @vat_rate])
      end
      
      it "should calculate the correct sales tax" do
        Spree::SalesTaxCalculator.should_receive(:calculate_tax).with(@order, {@tax_category => @sales_rate}).and_return(100)
        Spree::VatCalculator.should_receive(:calculate_tax).with(@order, {@tax_category => @vat_rate}).and_return(0)
        @order.calculate_tax.should == 100
      end

      it "should calculate the correct vat tax" do
        Spree::SalesTaxCalculator.should_receive(:calculate_tax).with(@order, {@tax_category => @sales_rate}).and_return(0)
        Spree::VatCalculator.should_receive(:calculate_tax).with(@order, {@tax_category => @vat_rate}).and_return(100)
        @order.calculate_tax.should == 100
      end
      
    end 
    
  end
end