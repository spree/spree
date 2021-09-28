require 'spec_helper'

describe Spree::Shipment do
  let(:shipment) { create(:shipment) }

  context '#ship' do
    before do
      allow(Spree::Webhooks::Endpoints::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
    end

    let(:payload) { {} }
    let(:queue_requests) { instance_double(Spree::Webhooks::Endpoints::QueueRequests) }

    it 'executes QueueRequests.call with a shipment.ship event and {} payload after invoking ship' do
      shipment.cancel # previous state that allows the object be shipped
      shipment.ship
      expect(queue_requests).to have_received(:call).with(event: 'shipment.ship', payload: payload).once
    end
  end
end
