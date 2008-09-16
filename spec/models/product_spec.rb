require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Product do

  before(:each) do
    @product = Product.new
  end

  ['name', 'master price', 'description'].each do |field|
    it "should require #{field}" do
      @product.valid?.should be_false
      @product.errors.full_messages.should include("#{field.capitalize} can't be blank")
    end
  end

  describe "#variants?" do
    it "should be false when variants is empty" do
      @product.variants.should be_empty
      @product.variants?.should be_false
    end

    it "should be false when none of the variants have option values" do
      variant_proxy = mock_model(Variant)
      variant_proxy.should_receive(:option_values).and_return([])
      @product.variants << variant_proxy
      @product.variants?.should be_false
    end

    it "should be true when at least one variant has option values" do
      ov_proxy = mock_model(OptionValue)
      variant_proxy = mock_model(Variant)
      variant_proxy.should_receive(:option_values).and_return([ov_proxy])
      @product.variants << variant_proxy
      @product.variants?.should be_true
    end
  end

  describe "#variant" do
    it "should return the emtpy variant if there are only empty variant" do
      variant = mock_model(Variant)
      variant.stub!(:option_values).and_return([])
      product = Product.new
      product.stub!(:variants).and_return([variant])
      product.variant.should == variant
    end

    it "should return nil if there are any non-empty variants" do
      variant1 = mock_model(Variant)
      variant1.stub!(:option_values).and_return([])
      ov = mock_model(OptionValue)
      variant2 = mock_model(Variant)
      variant2.stub!(:option_values).and_return([ov])
      product = Product.new
      product.stub!(:variants).and_return([variant1, variant2])
      product.variant.should be_nil
    end
  end

  describe "permalinks" do
    before(:each) do
      @product.name = "Air force ones"
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
      @product = create_product(:name => 'test 1', :available_on => (Time.now - 1.day))
      @old_product = create_product(:available_on => (Time.now + 2.weeks))
    end

    it "should only find availble products using the available class method" do
      Product.available.all.size.should eql(1)
    end

    it "should include available products" do
      Product.available.should include(@product)
    end
  end


  describe 'inventory' do

    before(:each) do
      @variant = mock_model(Variant, :on_hand => 45)
      @product = create_product
    end

    describe 'on_hand' do
      it "should return the number of items available for the first variant" do
        @product.stub!(:variant).and_return(@variant)
        @product.on_hand.should == 45
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

end

def create_product(options={})
  Product.create({
    :name => 'test product',
    :available_on => Time.now,
    :description => 'A test product',
    :master_price => 100.00,
  }.merge(options))
end
