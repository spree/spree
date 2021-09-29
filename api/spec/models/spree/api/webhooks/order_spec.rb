require 'spec_helper'

describe Spree::Order do
  describe 'sending webhooks after transitioning from states' do
    let(:payload) { {} }
    let(:queue_requests) { instance_double(Spree::Webhooks::Endpoints::QueueRequests) }
    let!(:store) { create(:store, default: true) }

    before do
      allow(Spree::Webhooks::Endpoints::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
    end

    context '#after_cancel' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it 'executes QueueRequests.call with a order.cancel event and {} payload after invoking cancel' do
        order.cancel
        expect(queue_requests).to have_received(:call).with(event: 'order.cancel', payload: payload).once
      end
    end

    context '#finalize!' do
      let(:order) { Spree::Order.create(email: 'test@example.com', store: store) }

      it 'executes QueueRequests.call with a order.complete event and {} payload after invoking finalize!' do
        order.finalize!
        expect(queue_requests).to have_received(:call).with(event: 'order.complete', payload: payload).once
      end
    end
  end
end
