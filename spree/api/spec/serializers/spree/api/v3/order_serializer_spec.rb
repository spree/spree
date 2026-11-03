require 'spec_helper'

RSpec.describe Spree::Api::V3::OrderSerializer do
  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store) }
  let(:params) { { store: store, locale: 'en', currency: store.default_currency, user: nil, includes: [], expand: [] } }

  before { Spree.hooks.register('returns.create.validate', 'Spree::Returns::EligibilityValidator') }

  describe 'returns_eligibility' do
    subject(:eligibility) { described_class.new(order, params: params.merge(returnability: true)).to_h['returns_eligibility'].deep_stringify_keys }

    it 'says the order is open to returns, with the window it closes on' do
      expect(eligibility).to include(
        'eligible' => true,
        'errors' => [],
        'return_window_ends_at' => (order.completed_at + 30.days).iso8601
      )
    end

    it 'gives the reason the create call would give once the window has closed' do
      order.update_columns(completed_at: 60.days.ago)

      expect(eligibility['eligible']).to be(false)
      expect(eligibility['errors'].first).to include('code' => 'outside_return_window')
    end
  end

  # Every rule is advisory for staff, and events never ask, so the customer's
  # verdict stays off the Admin API and webhook payloads.
  it 'is left out unless the Store order page asks' do
    expect(described_class.new(order, params: params).to_h).not_to have_key('returns_eligibility')
  end

  it 'is left out of the admin serializer' do
    admin = Spree::Api::V3::Admin::OrderSerializer.new(order, params: params).to_h

    expect(admin).not_to have_key('returns_eligibility')
    items = Spree::Api::V3::Admin::FulfillmentSerializer.new(order.fulfillments.first, params: params).to_h['items']
    expect(items.first.deep_stringify_keys.keys).to contain_exactly('item_id', 'variant_id', 'quantity')
  end
end
