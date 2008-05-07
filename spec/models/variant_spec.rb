require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Variant do
  
  before do
    @variant = Variant.new
  end

  it "should require a Product" do
    @variant.valid?.should be_false
    @variant.errors.full_messages.should include("Product can't be blank")
  end

  describe "with a valid product" do
    before do
      p = Product.new
      p.stub!(:valid?).and_return true
      @variant.stub!(:product).and_return p
    end

    it "should be valid with a price" do
      @variant.price = "12.50"
      @variant.valid?.should be_true
    end

    it "should use the product.master_price if there is no price" do
      @variant.product.should_receive(:master_price).exactly(2).and_return "11.33"
      @variant.valid?.should be_true
      @variant.price.should == BigDecimal.new("11.33")
    end

    it "should be invalid without a price or a product.master_price" do
      @variant.valid?.should be_false
      @variant.errors.full_messages.should include("Must supply price for variant or master_price for product.")
    end
  end
end
