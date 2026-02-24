# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::PostSerializer do
  let(:store) { @default_store }
  let(:post) { create(:post, store: store) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(post, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id title slug meta_title meta_description published_at
      author_id post_category_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(post.prefixed_id)
  end

  it 'returns prefixed author_id' do
    expect(subject['author_id']).to eq(post.author.prefixed_id)
  end

  it 'returns prefixed post_category_id' do
    expect(subject['post_category_id']).to eq(post.post_category.prefixed_id)
  end
end
