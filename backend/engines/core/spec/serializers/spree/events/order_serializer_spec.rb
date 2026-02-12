# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::OrderSerializer do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:order) do
    create(:completed_order_with_totals,
           store: store,
           user: user)
  end

  subject { described_class.serialize(order) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(order.prefixed_id)
      expect(subject[:number]).to eq(order.number)
    end

    it 'includes state attributes as strings' do
      expect(subject[:state]).to be_a(String)
      expect(subject[:payment_state]).to be_a(String)
      expect(subject[:shipment_state]).to be_a(String)
    end

    it 'includes totals' do
      expect(subject[:total]).to be_present
      expect(subject[:item_total]).to be_present
      expect(subject[:shipment_total]).to be_present
      expect(subject[:adjustment_total]).to be_present
      expect(subject[:promo_total]).to be_present
    end

    it 'includes tax totals' do
      expect(subject).to have_key(:included_tax_total)
      expect(subject).to have_key(:additional_tax_total)
    end

    it 'includes item count and currency' do
      expect(subject[:item_count]).to eq(order.item_count)
      expect(subject[:currency]).to eq(order.currency)
    end

    it 'includes email' do
      expect(subject[:email]).to eq(order.email)
    end

    it 'includes foreign keys' do
      expect(subject[:user_id]).to eq(user.prefixed_id)
      expect(subject[:store_id]).to eq(store.prefixed_id)
    end

    it 'includes timestamps' do
      expect(subject[:completed_at]).to be_present
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end

    it 'does not include associations' do
      expect(subject).not_to have_key(:line_items)
      expect(subject).not_to have_key(:shipments)
      expect(subject).not_to have_key(:payments)
    end
  end
end
