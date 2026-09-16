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
  describe 'actors' do
    let(:actor_names) { %w[created_by approver canceler] }
    let(:base_params) { { store: store, currency: store.default_currency, expand: actor_names } }

    context 'when a person performed the action' do
      let(:admin) { create(:admin_user, email: 'staff@example.com', first_name: 'Ada', last_name: 'Lovelace') }
      let(:order) { create(:order, store: store, created_by: admin, approver: admin, canceler: admin) }

      it 'names them by their id, kind and label' do
        actor_names.each do |actor|
          expect(subject[actor]['id']).to eq(admin.prefixed_id)
          expect(subject[actor]['type']).to eq('admin_user')
          expect(subject[actor]['label']).to eq('Ada Lovelace')
          expect(subject["#{actor}_id"]).to eq(admin.prefixed_id)
          expect(subject["#{actor}_type"]).to eq('admin_user')
        end
      end

      it 'exposes no customer-only attribute' do
        expect(subject['canceler']).not_to have_key('phone')
      end
    end

    context 'when an API key performed the action' do
      let(:key) { create(:api_key, :secret, store: store, name: 'WMS connector') }
      let(:order) { create(:order, store: store, created_by: key, approver: key, canceler: key) }

      it 'names the key rather than nobody' do
        actor_names.each do |actor|
          expect(subject[actor]['id']).to eq(key.prefixed_id)
          expect(subject[actor]['type']).to eq('api_key')
          expect(subject[actor]['label']).to eq('WMS connector')
          expect(subject["#{actor}_id"]).to eq(key.prefixed_id)
          expect(subject["#{actor}_type"]).to eq('api_key')
        end
      end
    end

    # A list page names three actors per row. Reading them off the columns
    # rather than through the association is what keeps that free.
    context 'when only the ids are rendered' do
      let(:admin) { create(:admin_user) }
      let(:order) { create(:order, store: store, created_by: admin, approver: admin, canceler: admin) }
      let(:base_params) { { store: store, currency: store.default_currency } }

      it 'names them without loading a single actor' do
        order.reload

        expect { subject }.not_to change { order.association(:canceler).loaded? }.from(false)
        expect(subject['canceler_id']).to eq(admin.prefixed_id)
        expect(subject['canceler_type']).to eq('admin_user')
      end
    end

    context 'when nobody is recorded' do
      let(:order) { create(:order, store: store) }

      it 'answers null on both halves' do
        actor_names.each do |actor|
          expect(subject["#{actor}_id"]).to be_nil
          expect(subject["#{actor}_type"]).to be_nil
        end
      end
    end
  end
end
