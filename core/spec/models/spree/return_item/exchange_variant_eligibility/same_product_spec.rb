require 'spec_helper'

module Spree
  module ReturnItem::ExchangeVariantEligibility
    describe SameProduct, :type => :model do
      describe ".eligible_variants" do
        it "returns all variants for the same product" do
          product = create(:product, variants: 3.times.map { create(:variant) })
          product.variants.map { |v| v.stock_items.first.update_column(:count_on_hand, 10) }

          expect(SameProduct.eligible_variants(product.variants.first).sort).to eq product.variants.sort
        end

        it "does not return variants for another product" do
          variant = create(:variant)
          other_product_variant = create(:variant)
          expect(SameProduct.eligible_variants(variant)).not_to include other_product_variant
        end

        it "only returns variants that are on hand" do
          product = create(:product, variants: 2.times.map { create(:variant) })
          in_stock_variant = product.variants.first

          in_stock_variant.stock_items.first.update_column(:count_on_hand, 10)
          expect(SameProduct.eligible_variants(in_stock_variant)).to eq [in_stock_variant]
        end
      end
    end
  end
end

