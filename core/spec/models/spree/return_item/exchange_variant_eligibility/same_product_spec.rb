require 'spec_helper'

module Spree
  module ReturnItem::ExchangeVariantEligibility
    describe SameProduct, type: :model do
      let(:store) { @default_store }

      describe '.eligible_variants' do
        context 'product has no variants' do
          it 'returns the master variant for the same product' do
            product = create(:product, stores: [store])
            product.master.stock_items.first.update_column(:count_on_hand, 10)

            expect(SameProduct.eligible_variants(product.master)).to eq [product.master]
          end
        end

        context 'product has variants' do
          it 'returns all variants for the same product' do
            product = create(:product, variants: Array.new(3) { create(:variant) }, stores: [store])
            product.variants.map { |v| v.stock_items.first.update_column(:count_on_hand, 10) }

            expect(SameProduct.eligible_variants(product.variants.first).sort).to eq product.variants.sort
          end
        end

        it 'does not return variants for another product' do
          variant = create(:variant)
          other_product_variant = create(:variant)
          expect(SameProduct.eligible_variants(variant)).not_to include other_product_variant
        end

        it 'only returns variants that are on hand or backorderable' do
          product = create(:product, variants: Array.new(3) { create(:variant) }, stores: [store])
          in_stock_variant = product.variants.first
          backorderable_variant = product.variants.second
          not_backorderable_variant = product.variants.third

          in_stock_variant.stock_items.first.update_column(:count_on_hand, 10)
          not_backorderable_variant.stock_items.first.update_column(:backorderable, false)

          expect(SameProduct.eligible_variants(in_stock_variant)).to include(in_stock_variant)
          expect(SameProduct.eligible_variants(in_stock_variant)).to include(backorderable_variant)
        end
      end
    end
  end
end
