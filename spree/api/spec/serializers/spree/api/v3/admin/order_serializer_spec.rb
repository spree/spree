require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OrderSerializer do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store) }
  let(:base_params) { { store: store, currency: store.default_currency } }

  subject { described_class.new(order, params: base_params).to_h }

  describe 'metadata' do
    context 'when order has metadata' do
      before { order.update!(metadata: { 'source' => 'mobile_app', 'campaign' => 'summer' }) }

      it 'returns the metadata' do
        expect(subject['metadata']).to eq({ 'source' => 'mobile_app', 'campaign' => 'summer' })
      end
    end

    context 'when order has no metadata' do
      it 'returns empty hash' do
        expect(subject['metadata']).to eq({})
      end
    end
  end

  describe 'items' do
    let(:order) { create(:order_with_line_items, store: store) }
    let(:base_params) { { store: store, currency: store.default_currency, expand: 'items' } }

    before { order.line_items.first.update!(metadata: { 'gift' => true }) }

    it 'uses admin line item serializer with metadata' do
      line_item_data = subject['items'].first
      expect(line_item_data).to have_key('metadata')
      expect(line_item_data['metadata']).to eq({ 'gift' => true })
    end
  end

  describe 'customer' do
    let(:order) { create(:order, store: store, customer: create(:user, email: 'buyer@example.com')) }
    let(:base_params) { { store: store, currency: store.default_currency, expand: 'customer' } }

    it 'embeds the customer through the renamed association' do
      expect(subject['customer']).to be_present
      expect(subject['customer']['id']).to eq(order.customer.prefixed_id)
      expect(subject['customer']['email']).to eq('buyer@example.com')
    end
  end

  # Regression: these three point at staff, and rendering them through the
  # customer serializer raised on the first customer-only attribute (phone)
  # as soon as the association was populated — which created_by now always is
  # on staff-created drafts.
  describe 'staff actors' do
    let(:admin) { create(:admin_user, email: 'staff@example.com') }
    let(:order) { create(:order, store: store, created_by: admin, approver: admin, canceler: admin) }
    let(:base_params) { { store: store, currency: store.default_currency, expand: %w[created_by approver canceler] } }

    it 'embeds them through the admin user serializer' do
      %w[created_by approver canceler].each do |actor|
        expect(subject[actor]['id']).to eq(admin.prefixed_id)
        expect(subject[actor]['email']).to eq('staff@example.com')
        expect(subject[actor]).not_to have_key('phone')
      end
    end
  end
end
