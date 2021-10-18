require 'spec_helper'

describe Spree::Api::V2::Platform::PriceSerializer do
  include_context 'API v2 serializers params'

  subject { described_class.new(price, params: serializer_params) }

  let(:price) { create(:price) }

  it { expect(subject.serializable_hash).to be_kind_of(Hash) }

  # serializable_hash is returned with a different key order,
  # making the tests fail if is compared to a pre-defined hash
  it do
    serializable_hash = subject.serializable_hash
    expect(serializable_hash[:data][:id]).to eq(price.id.to_s)
    expect(serializable_hash[:data][:type]).to eq(:price)
    expect(serializable_hash[:data][:attributes][:amount]).to eq(price.amount)
    expect(serializable_hash[:data][:attributes][:currency]).to eq(price.currency)
    expect(serializable_hash[:data][:attributes][:deleted_at]).to eq(price.deleted_at)
    expect(serializable_hash[:data][:attributes][:created_at]).to eq(price.created_at)
    expect(serializable_hash[:data][:attributes][:updated_at]).to eq(price.updated_at)
    expect(serializable_hash[:data][:attributes][:compare_at_amount]).to eq(price.compare_at_amount)
    expect(serializable_hash[:data][:attributes][:display_compare_at_price]).to eq(Spree::Money.new(0, currency: price.currency))
    expect(serializable_hash[:data][:attributes][:display_amount]).to eq(price.display_amount)
    expect(serializable_hash[:data][:attributes][:display_price]).to eq(price.display_price)
    expect(serializable_hash[:data][:attributes][:display_compare_at_price_including_vat_for]).to eq(Spree::Money.new(price.compare_at_amount, currency: price.currency))
    expect(serializable_hash[:data][:attributes][:display_compare_at_amount]).to eq(Spree::Money.new(0, currency: price.currency))
    expect(serializable_hash[:data][:attributes][:display_price_including_vat_for]).to eq(Spree::Money.new(price.amount, currency: price.currency))
  end
end
