require File.dirname(__FILE__) + '/../spec_helper'

module VariantSpecHelper
  def valid_variant_attributes
    {
      :sku => "mt",
      :price => 10,
      :weight => 1,
      :height => 1,
      :width => 1,
      :depth => 1
    }
  end
end


describe Variant do
  include VariantSpecHelper

  before(:each) do
    @variant = Variant.new
  end

  it "should not be valid when empty" do
    @variant.should_not be_valid
  end

  ['product'].each do |field|
    it "should require #{field}" do
      @variant.should_not be_valid
      @variant.errors.full_messages.should include("#{field.humanize} #{I18n.translate("activerecord.errors.messages.blank")}")
    end
  end

  describe "with a valid product" do
    before do
      p = Product.new
      p.stub!(:valid?).and_return true
      @variant.stub!(:product).and_return p
    end

    it "should be valid when having correct information" do
      @variant.attributes = valid_variant_attributes
      @variant.should be_valid
    end
  
    it "should set the price with the same value as its product master_price if not set" do
      @variant.product.should_receive(:master_price).exactly(2).and_return "11.33"
      @variant.valid?.should be_true
      @variant.price.should == BigDecimal.new("11.33")
    end

    it "should not be valid if the price and its product master_price is not set" do
      @variant.valid?.should be_false
      @variant.errors.full_messages.should include("Must supply price for variant or master_price for product.")
    end

    describe 'on_hand' do
      before do
        @variant.update_attributes!(valid_variant_attributes)
      end

      it "should update the inventory unit records when added" do
        @variant.inventory_units.size.should == 0

        @variant.update_attributes!({"on_hand" => "1"})
        @variant.inventory_units.size.should == 1
      end

      it "should update the inventory unit records when removed" do
        @variant.update_attributes!({"on_hand" => "2"})
        @variant.inventory_units.size.should == 2

        @variant.update_attributes!({"on_hand" => "1"})
        @variant.inventory_units.size.should == 1
        
        @variant.update_attributes!({"on_hand" => "0"})
        @variant.inventory_units.size.should == 0
      end
    end

    it "should return how many units are available when requested" do
        @variant.update_attributes!(valid_variant_attributes)
        @variant.on_hand.should == 0
        
        @variant.update_attributes!({"on_hand" => 3.to_s})
        @variant.on_hand.should == 3
    end
  
    it "should respond if it is in stock" do
        @variant.update_attributes!(valid_variant_attributes)
        @variant.in_stock.should == false
        
        @variant.update_attributes!({"on_hand" => 3.to_s})
        @variant.in_stock.should == true
    end
  end
end
