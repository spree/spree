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

  describe 'companies' do
    let!(:company) { create(:company, store: store, name: 'Acme Corp') }

    before { create(:company_membership, company: company, customer: customer) }

    # Behind an expand rather than always on: the company payload counts each
    # node's children and members, which a customers list that is not showing
    # them should not pay for.
    it 'is omitted unless expanded' do
      expect(subject).not_to have_key('companies')
    end

    it 'embeds the memberships when expanded' do
      result = described_class.new(customer, params: base_params.merge(expand: ['companies'])).to_h

      expect(result['companies'].map { |c| c['id'] }).to contain_exactly(company.prefixed_id)
      expect(result['companies'].first['name']).to eq('Acme Corp')
    end
  end
end
