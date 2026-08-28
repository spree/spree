# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::ImportSerializer do
  let(:store) { @default_store }
  let(:import) { create(:import) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(import, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id number type status store_id seller_id owner_type owner_id user_id rows_count
      created_at updated_at
    ])
  end

  it 'returns the store, and no seller for the operator\'s own import' do
    expect(subject['store_id']).to eq(import.store.prefixed_id)
    expect(subject['seller_id']).to be_nil
  end

  # `owner` shipped in 5.6 and is emitted from the new pair until 6.1, so the
  # two must agree.
  context 'the deprecated owner pair' do
    it 'names the store for an operator\'s import' do
      expect(subject['owner_type']).to eq('store')
      expect(subject['owner_id']).to eq(import.store.prefixed_id)
    end

    context 'when a seller ran it' do
      let(:seller) { create(:seller, store: store) }
      let(:import) { create(:import, store: store, seller: seller) }

      it 'names the seller' do
        expect(subject['seller_id']).to eq(seller.prefixed_id)
        expect(subject['owner_type']).to eq('seller')
        expect(subject['owner_id']).to eq(seller.prefixed_id)
      end
    end
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(import.prefixed_id)
  end

  it 'returns prefixed user_id' do
    expect(subject['user_id']).to eq(import.user.prefixed_id)
  end

  it 'returns status as string' do
    expect(subject['status']).to be_a(String)
  end
end
