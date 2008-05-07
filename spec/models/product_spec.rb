require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Product do
  
  before(:each) do
    @product = Product.new
  end
  
  it "should report no variants when variants is empty" do
    @product.variants?.should be_false
  end

  it "should report no variants when none of the variants have option values" do
    variant_proxy = mock_model(Variant)
    variant_proxy.should_receive(:option_values).and_return([])
    @product.variants << variant_proxy
    @product.variants?.should be_false
  end
  
  it "should report variants when all of the variants have option values" do
    ov_proxy = mock_model(OptionValue)
    variant_proxy = mock_model(Variant)
    variant_proxy.should_receive(:option_values).and_return([ov_proxy])
    @product.variants << variant_proxy
    @product.variants?.should be_true
  end
  
  it "variant should return the emtpy variant if the product contains only empty variant" do
    variant = mock_model(Variant)
    variant.stub!(:option_values).and_return([])
    product = Product.new
    product.stub!(:variants).and_return([variant])
    product.variant.should == variant
  end

  it "variant should return nil if the product contains non-empty variants" do
    variant1 = mock_model(Variant)
    variant1.stub!(:option_values).and_return([])
    ov = mock_model(OptionValue)
    variant2 = mock_model(Variant)
    variant2.stub!(:option_values).and_return([ov])
    product = Product.new
    product.stub!(:variants).and_return([variant1, variant2])
    product.variant.should be_nil
  end

  # TODO - Add the rest of the unit test stuff from product_test (once we're sure about tax treatment handling)
  describe "#before_create" do
    before do
      @p2 = Product.new(:name => "blah", :description => "blah2")
    end

    it "should create an empty variant" do
      @p2.should_receive(:empty_variant)
      @p2.save
    end

    describe "with no meaningful variant" do
      it "should not validate without a master price" do
        lambda {
          @p2.save!
        }.should raise_error(RuntimeError)
      end
    end
  end
end
