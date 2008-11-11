require File.dirname(__FILE__) + '/../spec_helper'

module ProductOptionTypeSpecHelper
  def valid_product_option_type_attributes
    {
      :position => 1
    }
  end
end


describe ProductOptionType do
  include ProductOptionTypeSpecHelper

  before(:each) do
    @product_option_type = ProductOptionType.new
  end

  it "should not be valid when empty" do
    pending "Shouldn't it require a position?"
    @product_option_type.should_not be_valid
  end

  ['position'].each do |field|
    it "should require #{field}" do
      pending "Shouldn't it require a position?"
      @product_option_type.should_not be_valid
      @product_option_type.errors.full_messages.should include("#{field.intern.l(field).humanize} #{:error_message_blank.l}")
    end
  end

  it "should be valid when having correct information" do
    pending "Shouldn't it require a product and an option type too?"
    @product_option_type.attributes = valid_product_option_type_attributes
    @product_option_type.should be_valid
  end

end
