require 'spec_helper'

describe Spree::OptionType do
  context "touching" do
    it "should touch a product" do
      product_option_type = create(:product_option_type)
      option_type = product_option_type.option_type
      product = product_option_type.product
      product.update_column(:updated_at, 1.day.ago)
      option_type.touch
      product.reload.updated_at.should be_within(3.seconds).of(Time.now)
    end
  end
end