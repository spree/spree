# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::NewsletterSubscriberSerializer do
  let(:store) { @default_store }
  let(:newsletter_subscriber) { create(:newsletter_subscriber, :verified) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(newsletter_subscriber, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id email verified verified_at user_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(newsletter_subscriber.prefixed_id)
  end

  it 'returns verified as boolean' do
    expect(subject['verified']).to be(true)
  end
end
