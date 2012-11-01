require 'spec_helper'

describe "Variant scopes" do
  let!(:product) { create(:product) }
  let!(:variant_1) { create(:variant, :product => product) }
  let!(:variant_2) { create(:variant, :product => product) }

  it ".descend_by_popularity" do
    # Requires a product with at least two variants, where one has a higher number of orders than the other
    create(:line_item, :variant => variant_1)
    Spree::Variant.descend_by_popularity.first.should == variant_1
  end

  context "finding by option values" do
    let!(:option_type) { create(:option_type, :name => "bar") }
    let!(:option_value_1) do
      option_value = create(:option_value, :name => "foo", :option_type => option_type)
      variant_1.option_values << option_value
      option_value
    end

    let!(:option_value_2) do
      option_value = create(:option_value, :name => "fizz", :option_type => option_type)
      variant_1.option_values << option_value
      option_value
    end

    let!(:product_variants) { product.variants_including_master }

    it "by objects" do
      variants = product_variants.has_option(option_type, option_value_1)
      variants.should include(variant_1)
      variants.should_not include(variant_2)
    end

    it "by names" do
      variants = product_variants.has_option("bar", "foo")
      variants.should include(variant_1)
      variants.should_not include(variant_2)
    end

    it "by ids" do
      variants = product_variants.has_option(option_type.id, option_value_1.id)
      variants.should include(variant_1)
      variants.should_not include(variant_2)
    end

    it "by mixed conditions" do
      variants = product_variants.has_option(option_type.id, "foo", option_value_2)
    end
  end
end
