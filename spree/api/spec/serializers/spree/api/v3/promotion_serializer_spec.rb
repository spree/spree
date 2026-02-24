# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::PromotionSerializer do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(promotion, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id name description code type kind path match_policy usage_limit
      advertise multi_codes code_prefix number_of_codes
      starts_at expires_at promotion_category_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(promotion.prefixed_id)
  end

  it 'returns the promotion name' do
    expect(subject['name']).to eq('Promo')
  end
end
