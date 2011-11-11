require 'spec_helper'

describe "Variant scopes" do
  let!(:product) { Factory(:product) }
  let!(:variant_1) { Factory(:variant, :product => product) }
  let!(:variant_2) { Factory(:variant, :product => product) }

  it ".descend_by_popularity" do
    # Requires a product with at least two variants, where one has a higher number of orders than the other
    Factory(:line_item, :variant => variant_1)
    Spree::Variant.descend_by_popularity.first.should == variant_1
  end

  it "finding by option values" do
    option_type = Factory(:option_type, :name => "bar")
    option_value = Factory(:option_value, :name => "foo", :option_type => option_type)
    variant_1.option_values << option_value
    variant_1.save

    variants = product.variants_including_master.has_option(option_type, option_value)
    variants.should include(variant_1)
  end
end
