# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::PostCategorySerializer do
  let(:store) { @default_store }
  let(:post_category) { create(:post_category, store: store) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(post_category, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id title slug created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(post_category.prefixed_id)
  end
end
