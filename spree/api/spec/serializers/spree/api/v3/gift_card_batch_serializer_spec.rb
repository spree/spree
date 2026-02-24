# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::GiftCardBatchSerializer do
  let(:store) { @default_store }
  let(:gift_card_batch) { create(:gift_card_batch, amount: 25.00, prefix: 'GC', currency: 'USD') }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(gift_card_batch, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id codes_count amount currency prefix expires_at created_by_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(gift_card_batch.prefixed_id)
  end

  it 'returns amount as string' do
    expect(subject['amount']).to eq('25.0')
  end
end
