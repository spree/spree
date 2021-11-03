require 'spec_helper'

describe Spree::Shipment do
  let(:order) { create(:order) }
  let(:shipment) { create(:shipment) }

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

    context 'emitting shipment.shipped' do
      let(:body) { Spree::Api::V2::Platform::ShipmentSerializer.new(shipment).serializable_hash.to_json }

      shared_examples 'emits shipment.shipped' do
        it do
          expect(queue_requests).to have_received(:call).with(event: 'shipment.shipped', body: body).once
        end
      end

      context 'ready -> ship' do
        let(:shipment) { create(:shipment, order: order) }

        before do
          order.update(state: 'complete', completed_at: Time.current)
          shipment.reload
          shipment.ready
          shipment.ship
        end

        include_examples 'emits shipment.shipped'
      end

      context 'canceled -> ship' do
        before do
          shipment.cancel
          shipment.ship
        end

        include_examples 'emits shipment.shipped'
      end
    end

    context 'emitting order.shipped' do
      let(:body) do
        order.reload
        Spree::Api::V2::Platform::OrderSerializer.new(order).serializable_hash.to_json
      end
      let!(:shipments) do
        create_list(
          :shipment, 2,
          order: order,
          shipping_methods: [create(:shipping_method)],
          stock_location: build(:stock_location)
        )
      end

      shared_examples 'does not emit order.shipped' do
        it do
          expect(queue_requests).not_to have_received(:call).with(event: 'order.shipped', body: body)
        end
      end

      context 'ready -> ship' do
        before do
          order.update(state: 'complete', completed_at: Time.current)
          shipments.each(&:reload) # must reload to make shipments order state see it's complete
          shipments[0].ready
          shipments[0].ship
        end

        context 'with all order shipments shipped' do
          it 'emits order.shipped' do
            shipments[1].ready
            shipments[1].ship
            expect(queue_requests).to have_received(:call).with(event: 'order.shipped', body: body).once
          end
        end

        context 'without all order shipments shipped' do
          include_examples 'does not emit order.shipped'
        end
      end

      context 'canceled -> ship' do
        before do
          shipments[0].cancel
          shipments[0].ship
        end

        context 'with all order shipments shipped' do
          it 'emits order.shipped' do
            shipments[1].cancel
            shipments[1].ship
            expect(queue_requests).to have_received(:call).with(event: 'order.shipped', body: body).once
          end
        end

        context 'without all order shipments shipped' do
          include_examples 'does not emit order.shipped'
        end
      end
    end
  end
end
