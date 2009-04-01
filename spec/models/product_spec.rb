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

  it "should not be valid when empty" do
    @product.should_not be_valid
  end

  ['Name', 'Master Price'].each do |field|
    it "should require #{field}" do
      @product.should_not be_valid
      @product.errors.full_messages.should include("#{field} #{I18n.translate("activerecord.errors.messages.blank")}")
    end
  end

  it "should be valid when having correct information" do
    @product.attributes = valid_product_attributes
    @product.should be_valid
  end

  describe "#variants?" do
    it "should be false when variants is empty" do
      @product.variants.should be_empty
      @product.variants?.should be_false
    end

    it "should be false when none of the variants have option values" do
      variant = mock_model(Variant)
      variant.should_receive(:option_values).and_return([])
      @product.variants << variant
      @product.variants?.should be_false
    end

    it "should be true when at least one variant has option values" do
      option_value = mock_model(OptionValue)
      variant = mock_model(Variant)
      variant.should_receive(:option_values).and_return([option_value])
      @product.variants << variant
      @product.variants?.should be_true
    end
  end

  describe "#variant" do
    it "should return the emtpy variant if there are only empty variant" do
      variant = mock_model(Variant)
      variant.stub!(:option_values).and_return([])
      @product.stub!(:variants).and_return([variant])
      @product.variant.should == variant
    end

    it "should return nil if there are any non-empty variants" do
      variant1 = mock_model(Variant)
      variant1.stub!(:option_values).and_return([])
      option_value = mock_model(OptionValue)
      variant2 = mock_model(Variant)
      variant2.stub!(:option_values).and_return([option_value])
      @product.stub!(:variants).and_return([variant1, variant2])
      @product.variant.should be_nil
    end
  end

  describe "permalinks" do
    before(:each) do 
      @product = Product.new(:name => "Air force ones", :description => "Whatever", :master_price => 10.00)
    end

    it "should not have a nil permalink with a saved name" do
      @product.save
      @product.permalink.should_not be_nil
    end

    it "should save the correct permalink" do
      @product.save
      @product.permalink.should eql('air-force-ones')
    end
  end

  describe "availability" do
    before(:each) do
      @product = Product.create(valid_product_attributes.with(:available_on => (Time.now - 1.day)))
      @not_available_product = Product.create(valid_product_attributes.with(:available_on => (Time.now + 2.weeks)))
    end

    it "should only find available products using the available class method" do
      Product.available.all.size.should eql(1)
    end

    it "should include available products" do
      Product.available.should include(@product)
    end
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
        @variant.stub!(:in_stock).and_return(true)
        @product.stub!(:variants).and_return([@variant])
        @product.has_stock?.should be_true
      end

      it "should be false if all variants are out of stock" do
        @variant.stub!(:in_stock).and_return(false)
        @product.stub!(:variants).and_return([@variant])
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
    @product.variants.stub!(:first).and_return(@variant)
    @variant.should_receive(:price=).with(20)
    @product.update_attributes!({"master_price" => "20"})
  end
end
