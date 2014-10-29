require 'spec_helper'

module Spree
  module ReturnItem::ExchangeVariantEligibility
    describe SameProduct, :type => :model do
      describe ".eligible_variants" do
        it "returns all other variants for the same product" do
          product = create(:product, variants: 3.times.map { build(:variant) })
          expect(SameProduct.eligible_variants(product.variants.first).sort).to eq product.variants[1..-1].sort
        end

        it "does not return variants for another product" do
          variant = create(:variant)
          other_product_variant = create(:variant)
          expect(SameProduct.eligible_variants(variant)).not_to include other_product_variant
        end
      end
    end
  end
end

