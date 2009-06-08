require File.dirname(__FILE__) + '/../spec_helper'

module ProductSpecHelper
  def valid_product_attributes
    {
      :name => "A Product",
      :master_price => 10,
      :description => "Just a test product."
    }
  end

  def valid_variant_attributes
    {
      :on_hand => 45,
      :sku => "un"
    }
  end
end


describe Product do
  include ProductSpecHelper

  before(:each) do
    @product = Product.new
  end




  describe 'inventory' do

    before(:each) do
      @variant = Variant.create(valid_variant_attributes)
      @product.attributes = valid_product_attributes
    end

    describe 'on_hand' do
      it "should return the number of items available for the first variant" do
        @product.stub!(:variant).and_return(@variant)
        @variant.stub!(:on_hand).and_return(45)
        @product.on_hand.should == 45
      end

      it "should update the inventory unit records of the corresponding variant when added" do
        @product.save
        @variant = Variant.create!({"price" => "10", "product" => @product})

        @product.variant.inventory_units.size.should == 0
        
        @product.update_attributes!({"on_hand" => "1"})
        @product.variant.inventory_units.size.should == 1
      end

      it "should update the inventory unit records of the corresponding variant when removed" do
        @product.save
        @variant = Variant.create!({"price" => "10", "product" => @product})

        @product.variant.inventory_units.size.should == 0

        @product.update_attributes!({"on_hand" => "2"})
        @product.variant.inventory_units.size.should == 2
        
        @product.update_attributes!({"on_hand" => "1"})
        @product.variant.inventory_units.size.should == 1
        
        @product.update_attributes!({"on_hand" => "0"})
        @product.variant.inventory_units.size.should == 0
      end
    end
    
    describe 'sku' do 
      it "should return the stock keeping unit for the first variant" do
        @product.stub!(:variant).and_return(@variant)
        @product.sku.should == "un"
      end

      it "should update the stock keeping unit of the corresponding variant when changed" do
        @product.stub!(:variant).and_return(@variant)
        @product.sku = "mt"
        @variant.sku.should == "mt"
      end
    end

    describe 'has_stock?' do
      it "should be true if any variants are in stock" do
        @variant.stub!(:in_stock, :return => true)
        @product.stub!(:variants, :return => [@variant])
        @product.has_stock?.should be_true
      end

      it "should be false if all variants are out of stock" do
        @variant.stub!(:in_stock, :return => false)
        @product.stub!(:variants, :return => [@variant])
        @product.has_stock?.should be_false
      end
    end

  end

  it "should update the inventory unit records of the corresponding variant with an initial value when created" do
    @product.save
    if @product.variants.empty?
      @product.available_on = Time.now
      @product.variants << Variant.new(:product => @product)
    end

    @product.update_attributes!(valid_product_attributes.with("on_hand" => "2"))
    
    first_size = @product.variant.inventory_units.size
    first_size.should == 2
  end

  it "should update the empty variant if the 'master_price' attribute is changed" do
    @variant = Variant.create(valid_variant_attributes)
    @product.update_attributes!(valid_product_attributes)
    @product.variants << @variant
    @variant.should_receive(:price=).with(20)
    @product.update_attributes!({"master_price" => "20"})
  end
end
