require 'spec_helper'

describe "Variant scopes" do
  it ".descend_by_popularity" do
    # Requires a product with at least two variants, where one has a higher number of orders than the other
    product = Factory(:product)
    variant_1 = Factory(:variant, :product => product)
    variant_2 = Factory(:variant, :product => product)
    Factory(:line_item, :variant => variant_1)
    Spree::Variant.descend_by_popularity.first.should == variant_1
  end
end
