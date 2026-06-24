# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomerSerializer do
  let(:store) { @default_store }
  let(:customer) { create(:user) }
  let(:base_params) { { store: store, currency: 'USD' } }

  subject { described_class.new(customer, params: base_params).to_h }

  it 'returns the prefixed id' do
    expect(subject['id']).to eq(customer.prefixed_id)
  end

  describe 'customer_group_ids' do
    it 'is always present, even with no membership' do
      expect(subject['customer_group_ids']).to eq([])
    end

    it 'exposes group membership as prefixed ids' do
      group = create(:customer_group, store: store)
      customer.customer_groups << group

      expect(subject['customer_group_ids']).to contain_exactly(group.prefixed_id)
    end
  end
end
