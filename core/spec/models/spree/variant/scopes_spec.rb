require 'spec_helper'

describe 'Variant scopes', type: :model do
  let!(:product_1) { create(:product, name: 'First product') }
  let!(:product_2) { create(:product, name: 'Second product') }
  let!(:product_3) { create(:product, name: 'Third product') }

  let!(:variant_1) { create(:variant, product: product_1, sku: 'first_variant_red') }
  let!(:variant_2) { create(:variant, product: product_2, sku: 'second_variant_green') }
  let!(:variant_3) { create(:variant, product: product_3, sku: 'third_variant_blue') }

  describe '#product_name_or_sku_cont' do
    it 'returns variants based on products name' do
      expect(Spree::Variant.product_name_or_sku_cont('Second')).to include(variant_2)
    end

    it 'returns variants based on variant sku' do
      expect(Spree::Variant.product_name_or_sku_cont('blue')).to include(variant_3)
    end

    it 'does not return variants of products that do not match name' do
      expect(Spree::Variant.product_name_or_sku_cont('First')).not_to include(variant_2, variant_3)
    end

    it 'does not return variants with not matching skus' do
      expect(Spree::Variant.product_name_or_sku_cont('green')).not_to include(variant_1, variant_3)
    end

    it 'returns multiple variants based on products name' do
      expect(Spree::Variant.product_name_or_sku_cont('product')).to include(variant_1, variant_2, variant_3)
    end

    it 'return multiple variants based on variants sku' do
      expect(Spree::Variant.product_name_or_sku_cont('variant')).to include(variant_1, variant_2, variant_3)
    end

    it 'returns no variants when products name does not match any' do
      variants = Spree::Variant.product_name_or_sku_cont('White dress')
      expect(variants).not_to include(variant_1, variant_2, variant_3)
      expect(variants.count).to eq(0)
    end

    it 'returns no variants when variants sku does not match any' do
      variants = Spree::Variant.product_name_or_sku_cont('variant_white')
      expect(variants).not_to include(variant_1, variant_2, variant_3)
      expect(variants.count).to eq(0)
    end
  end

  describe '#search_by_product_name_or_sku' do
    it 'returns variants based on products name' do
      expect(Spree::Variant.search_by_product_name_or_sku('Second')).to include(variant_2)
    end

    it 'returns variants based on variant sku' do
      expect(Spree::Variant.search_by_product_name_or_sku('blue')).to include(variant_3)
    end

    it 'does not return variants of products that do not match name' do
      expect(Spree::Variant.search_by_product_name_or_sku('First')).not_to include(variant_2, variant_3)
    end

    it 'does not return variants with not matching skus' do
      expect(Spree::Variant.search_by_product_name_or_sku('green')).not_to include(variant_1, variant_3)
    end

    it 'returns multiple variants based on products name' do
      expect(Spree::Variant.search_by_product_name_or_sku('product')).to include(variant_1, variant_2, variant_3)
    end

    it 'return multiple variants based on variants sku' do
      expect(Spree::Variant.search_by_product_name_or_sku('variant')).to include(variant_1, variant_2, variant_3)
    end

    it 'returns no variants when products name does not match any' do
      variants = Spree::Variant.search_by_product_name_or_sku('White dress')
      expect(variants).not_to include(variant_1, variant_2, variant_3)
      expect(variants.count).to eq(0)
    end

    it 'returns no variants when variants sku does not match any' do
      variants = Spree::Variant.search_by_product_name_or_sku('variant_white')
      expect(variants).not_to include(variant_1, variant_2, variant_3)
      expect(variants.count).to eq(0)
    end
  end
end
