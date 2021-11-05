require 'spec_helper'

describe Spree::Order do
  let(:store) { create(:store, default: true) }
  let(:body) do
    Spree::Api::V2::Platform::OrderSerializer.new(order, serializer_params(event: params)).serializable_hash.to_json
  end

  describe 'order.canceled' do
    describe 'completed -> canceled' do
      let(:params) { 'order.canceled' }
      let(:order) { create(:completed_order_with_totals, store: store) }

      it { expect { Timecop.freeze { order.cancel } }.to emit_webhook_event(params) }
    end
  end

  describe 'order.placed' do
    describe 'checkout -> completed' do
      let(:params) { 'order.placed' }
      let(:order) { described_class.create(email: 'test@example.com', store: store) }

      it { expect { Timecop.freeze { order.finalize! } }.to emit_webhook_event(params) }
    end
  end

  describe 'order.resumed' do
    describe 'canceled -> resumed' do
      let(:params) { 'order.resumed' }
      let(:order) { create(:order, store: store, state: :canceled) }

      it { expect { Timecop.freeze { order.resume! } }.to emit_webhook_event(params) }
    end
  end
end
