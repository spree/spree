require 'spec_helper'

describe Spree::Api::Webhooks::OrderDecorator do
  let(:store) { create(:store, default: true) }
  let(:body) do
    Spree::Api::V2::Platform::OrderSerializer.new(order).serializable_hash.to_json
  end

  describe 'order.canceled' do
    describe 'completed -> canceled' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it { expect { Timecop.freeze { order.cancel } }.to emit_webhook_event('order.canceled') }
    end
  end

  describe 'order.placed' do
    describe 'checkout -> completed' do
      let(:order) { create(:order, email: 'test@example.com', store: store) }

      it { expect { Timecop.freeze { order.finalize! } }.to emit_webhook_event('order.placed') }
    end
  end

  describe 'order.resumed' do
    describe 'canceled -> resumed' do
      let(:order) { create(:order, store: store, state: :canceled) }

      it { expect { Timecop.freeze { order.resume! } }.to emit_webhook_event('order.resumed') }
    end
  end
end
