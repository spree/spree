require File.dirname(__FILE__) + '/../spec_helper'

module ProductPropertySpecHelper
  def valid_product_property_attributes
    {
      :value => "x"
    }
  end
end


describe ProductProperty do
  include ProductPropertySpecHelper

  before(:each) do
    @product_property = ProductProperty.new
  end

  it "should not be valid when empty" do
    @product_property.should_not be_valid
  end

  it "should be valid when having correct information" do
    pending "Shouldn't it require a product and a property too?"
    @product_property.attributes = valid_product_property_attributes
    @product_property.should be_valid
  end

end
