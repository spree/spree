require 'spec_helper'

describe Spree::Order do
  describe 'sending webhooks after transitioning from states' do
    let(:queue_requests) { instance_double(Spree::Webhooks::Endpoints::QueueRequests) }
    let(:store) { create(:store, default: true) }
    let(:body) do
      Spree::Api::V2::Platform::OrderSerializer.new(order).serializable_hash.to_json
    end

    before do
      ENV['DISABLE_SPREE_WEBHOOKS'] = nil
      allow(Spree::Webhooks::Endpoints::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
    end

    after { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

    describe '#after_cancel' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it 'executes QueueRequests.call with a order.cancel event and {} body after invoking cancel' do
        Timecop.freeze(Time.local(1990)) do
          order.cancel
          expect(queue_requests).to have_received(:call).with(event: 'order.cancel', body: body).once
        end
      end
    end

    describe '#finalize!' do
      let(:order) { described_class.create(email: 'test@example.com', store: store) }

      it 'executes QueueRequests.call with a order.complete event and {} body after invoking finalize!' do
        order.finalize!
        expect(queue_requests).to have_received(:call).with(event: 'order.complete', body: body).once
      end
    end
  end
end
