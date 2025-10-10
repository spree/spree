require 'spec_helper'

RSpec.describe Spree::V2::Storefront::LineItemSerializer do
  subject { described_class.new(line_item).serializable_hash }

  include_context 'API v2 serializers params'

  let!(:line_item) { create(:line_item) }

  it { expect(subject).to be_kind_of(Hash) }

  describe 'attributes' do
    it 'returns expected attributes' do
      expect(subject[:data][:attributes]).to include(
        name: line_item.name,
        quantity: line_item.quantity,
        price: line_item.price,
        slug: line_item.slug,
        options_text: line_item.options_text,
        currency: line_item.currency,
        display_price: line_item.display_price,
        total: line_item.total,
        display_total: line_item.display_total,
        adjustment_total: line_item.adjustment_total,
        display_adjustment_total: line_item.display_adjustment_total,
        additional_tax_total: line_item.additional_tax_total,
        discounted_amount: line_item.discounted_amount,
        display_discounted_amount: line_item.display_discounted_amount,
        display_additional_tax_total: line_item.display_additional_tax_total,
        promo_total: line_item.promo_total,
        display_promo_total: line_item.display_promo_total,
        included_tax_total: line_item.included_tax_total,
        display_included_tax_total: line_item.display_included_tax_total,
        pre_tax_amount: line_item.pre_tax_amount,
        display_pre_tax_amount: line_item.display_pre_tax_amount,
        compare_at_amount: line_item.compare_at_amount,
        display_compare_at_amount: line_item.display_compare_at_amount,
        public_metadata: line_item.public_metadata
      )
    end
  end

  describe 'relationships' do
    it 'includes variant relationship' do
      expect(subject[:data][:relationships]).to have_key(:variant)
    end

    it 'includes digital_links relationship' do
      expect(subject[:data][:relationships]).to have_key(:digital_links)
    end
  end
end
