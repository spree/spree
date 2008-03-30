require File.dirname(__FILE__) + '/../../spec_helper.rb'

describe Spree::BaseHelper do
  it "sku should return nil if the product contains only empty variant" do
    variant = mock_model(Variant)
    variant.should_receive(:sku).and_return nil
    product = mock_model(Product)
    product.stub!(:variants).and_return([variant])
    product.stub!(:variants?).and_return(false)
    sku(product).should be_nil
  end

  it "sku should return value if prduct has a single empty variant with sku" do
    variant = mock_model(Variant, :sku => "ABC123")
    #variant.should_receive(:option_values).and_return([])
    product = mock_model(Product)
    product.stub!(:variants).and_return([variant])
    product.stub!(:variants?).and_return(false)
    sku(product).should == "ABC123"
  end
  
  it "sku should return nil if product has non-empty variants with skus" do
    variant1 = mock_model(Variant, :sku => "ABC123")
    variant2 = mock_model(Variant, :sku => "ABC456")
    product = mock_model(Product)
    product.stub!(:variants).and_return([variant1, variant2])
    product.stub!(:variants?).and_return(true)
    sku(product).should be_nil
  end
  
  it "sku should return nil if product has non-empty variants without skus" do
    variant1 = mock_model(Variant)
    variant2 = mock_model(Variant)
    product = mock_model(Product)
    product.stub!(:variants).and_return([variant1, variant2])
    product.stub!(:variants?).and_return(true)
    sku(product).should be_nil
  end
  
end