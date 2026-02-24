# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::ReportSerializer do
  let(:store) { @default_store }
  let(:report) { create(:report) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(report, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id type user_id currency date_from date_to created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(report.prefixed_id)
  end

  it 'returns prefixed user_id' do
    expect(subject['user_id']).to eq(report.user.prefixed_id)
  end

  it 'returns date_from as ISO8601' do
    expect(subject['date_from']).to be_present
  end
end
