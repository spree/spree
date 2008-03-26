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
  
  # TODO - Add the rest of the unit test stuff from product_test (once we're sure about tax treatment handling)
end