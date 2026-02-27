require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OrderSerializer do
  let(:store) { @default_store }
  let(:order) { create(:order, store: store) }
  let(:base_params) { { store: store, currency: store.default_currency } }

  subject { described_class.new(order, params: base_params).to_h }

  describe 'metadata' do
    context 'when order has metadata' do
      before { order.update!(private_metadata: { 'source' => 'mobile_app', 'campaign' => 'summer' }) }

      it 'returns the metadata' do
        expect(subject['metadata']).to eq({ 'source' => 'mobile_app', 'campaign' => 'summer' })
      end
    end

    context 'when order has no metadata' do
      it 'returns nil' do
        expect(subject['metadata']).to be_nil
      end
    end
  end

  describe 'line_items' do
    let(:order) { create(:order_with_line_items, store: store) }

    before { order.line_items.first.update!(private_metadata: { 'gift' => true }) }

    it 'uses admin line item serializer with metadata' do
      line_item_data = subject['line_items'].first
      expect(line_item_data).to have_key('metadata')
      expect(line_item_data['metadata']).to eq({ 'gift' => true })
    end
  end
end
