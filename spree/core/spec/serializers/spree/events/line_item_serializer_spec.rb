# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::LineItemSerializer do
  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:line_item) { order.line_items.first }

  subject { described_class.serialize(line_item) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(line_item.prefixed_id)
    end

    it 'includes quantity' do
      expect(subject[:quantity]).to eq(line_item.quantity)
    end

    it 'includes price fields' do
      expect(subject[:price]).to be_present
      expect(subject[:currency]).to eq(line_item.currency)
      expect(subject).to have_key(:cost_price)
    end

    it 'includes adjustment totals' do
      expect(subject).to have_key(:adjustment_total)
      expect(subject).to have_key(:additional_tax_total)
      expect(subject).to have_key(:promo_total)
      expect(subject).to have_key(:included_tax_total)
      expect(subject).to have_key(:pre_tax_amount)
      expect(subject).to have_key(:taxable_adjustment_total)
      expect(subject).to have_key(:non_taxable_adjustment_total)
    end

    it 'includes foreign keys' do
      expect(subject[:variant_id]).to eq(line_item.variant&.prefixed_id)
      expect(subject[:order_id]).to eq(order.prefixed_id)
      expect(subject).to have_key(:tax_category_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
