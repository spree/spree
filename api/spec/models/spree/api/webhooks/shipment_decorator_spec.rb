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

    it 'emits a shipment.shipped event' do
      shipment.cancel # previous state that allows the object be shipped
      shipment.ship
      expect(queue_requests).to have_received(:call).with(event: 'shipment.shipped', body: body).once
    end

    context 'emitting order.shipped' do
      let(:body) do
        order.reload
        Spree::Api::V2::Platform::OrderSerializer.new(order).serializable_hash.to_json
      end
      let(:order) { create(:order) }
      let!(:shipments) do
        create_list(
          :shipment, 2,
          order: order,
          shipping_methods: [create(:shipping_method)],
          stock_location: build(:stock_location)
        )
      end

      context 'when all order shipments were shipped' do
        it 'emits an order.shipped event' do
          shipments[0].cancel
          shipments[0].ship
          shipments[1].cancel
          shipments[1].ship
          expect(queue_requests).to have_received(:call).with(event: 'order.shipped', body: body).once
        end
      end

      context 'when not all order shipments were shipped' do
        it 'does not emits an order.shipped event' do
          shipments[0].cancel
          shipments[0].ship
          expect(queue_requests).not_to have_received(:call).with(event: 'order.shipped', body: body)
        end
      end
    end
  end
end
