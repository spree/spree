# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::GiftCardBatchSerializer do
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:gift_card_batch) do
    create(:gift_card_batch,
           store: store,
           created_by: admin_user,
           amount: 50.00,
           currency: 'USD',
           codes_count: 10,
           prefix: 'GIFT')
  end

  subject { described_class.serialize(gift_card_batch) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(gift_card_batch.prefixed_id)
    end

    it 'includes codes_count' do
      expect(subject[:codes_count]).to eq(10)
    end

    it 'includes amount fields' do
      expect(subject[:amount]).to eq(50.00)
      expect(subject[:currency]).to eq('USD')
    end

    it 'includes prefix' do
      expect(subject).to have_key(:prefix)
    end

    it 'includes expires_at' do
      expect(subject).to have_key(:expires_at)
    end

    it 'includes foreign keys' do
      expect(subject[:store_id]).to eq(store.prefixed_id)
      expect(subject[:created_by_id]).to eq(admin_user.prefixed_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
