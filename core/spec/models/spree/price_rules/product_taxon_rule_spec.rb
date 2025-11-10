require 'spec_helper'

describe Spree::PriceRules::ProductTaxonRule, type: :model do
  let(:price_list) { create(:price_list) }
  let(:rule) { create(:product_taxon_price_rule, price_list: price_list) }
  let(:taxon) { create(:taxon) }
  let(:product) { create(:product, taxons: [taxon]) }
  let(:variant) { product.master }

  describe '#applicable?' do
    context 'when taxon_ids preference is empty' do
      before { rule.preferred_taxon_ids = [] }

      it 'returns true for any product' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD')
        expect(rule.applicable?(context)).to be true
      end
    end

    context 'when taxon_ids preference is set' do
      before { rule.preferred_taxon_ids = [taxon.id] }

      it 'returns true when product has matching taxon' do
        context = Spree::Pricing::Context.new(variant: variant, currency: 'USD')
        expect(rule.applicable?(context)).to be true
      end

      it 'returns false when product does not have matching taxon' do
        other_product = create(:product)
        context = Spree::Pricing::Context.new(variant: other_product.master, currency: 'USD')
        expect(rule.applicable?(context)).to be false
      end
    end
  end
end
