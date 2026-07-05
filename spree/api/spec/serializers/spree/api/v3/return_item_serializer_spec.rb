# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::ReturnItemSerializer do
  let(:store) { @default_store }
  let(:return_item) { create(:return_item) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(return_item, params: base_params).to_h }

  it 'includes all expected attributes' do
    expect(subject.keys).to match_array(%w[
      id reception_status acceptance_status pre_tax_amount
      included_tax_total additional_tax_total inventory_unit_id
      return_authorization_id customer_return_id reimbursement_id
      exchange_variant_id created_at updated_at
    ])
  end

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(return_item.prefixed_id)
  end

  it 'returns prefixed inventory_unit_id' do
    expect(subject['inventory_unit_id']).to eq(return_item.inventory_unit.prefixed_id)
  end
end
