require 'spec_helper'

describe Spree::Shipment do
  let(:shipment) { create(:shipment) }
  let(:body) { Spree::Api::V2::Platform::ShipmentSerializer.new(shipment).serializable_hash.to_json }

  describe '#after_ship' do
    before do
      ENV['DISABLE_SPREE_WEBHOOKS'] = nil
      # Avoid creating a new state change after transitioning as is defined in the model
      # because after_ship queues the HTTP request before finishing the transition, hence
      # the total state changes that are sent in the body is one less.
      allow(shipment).to receive_message_chain(:state_changes, :create!)
      allow(Spree::Webhooks::Subscribers::QueueRequests).to receive(:new).and_return(queue_requests)
      allow(queue_requests).to receive(:call).with(any_args)
    end

    after { ENV['DISABLE_SPREE_WEBHOOKS'] = 'true' }

    let(:queue_requests) { instance_double(Spree::Webhooks::Subscribers::QueueRequests) }

    it 'executes QueueRequests.call with a shipment.shipped event and {} body after invoking ship' do
      shipment.cancel # previous state that allows the object be shipped
      shipment.ship
      expect(queue_requests).to have_received(:call).with(event: 'shipment.shipped', body: body).once
    end
  end
end
