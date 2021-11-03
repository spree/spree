require 'spec_helper'

describe Spree::Shipment do
  let(:order) { create(:order) }
  let(:shipment) { create(:shipment) }

  describe '#after_ship' do
    before do
      # Avoid creating a new state change after transitioning as is defined in the model
      # because after_ship queues the HTTP request before finishing the transition, hence
      # the total state changes that are sent in the body is one less.
      allow(shipment).to receive_message_chain(:state_changes, :create!)
    end

    context 'emitting shipment.shipped' do
      let(:body) { Spree::Api::V2::Platform::ShipmentSerializer.new(shipment).serializable_hash.to_json }

      context 'ready -> ship' do
        let(:shipment) { create(:shipment, order: order) }

        before do
          order.update(state: 'complete', completed_at: Time.current)
          shipment.reload
          shipment.ready
        end

        it { expect { shipment.ship }.to emit_webhook_event('shipment.shipped') }
      end

      context 'canceled -> ship' do
        before { shipment.cancel }

        it { expect { shipment.ship }.to emit_webhook_event('shipment.shipped') }
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

      context 'ready -> ship' do
        before do
          order.update(state: 'complete', completed_at: Time.current)
          shipments.each(&:reload) # must reload to make shipments order state see it's complete
          shipments[0].ready
        end

        context 'with all order shipments shipped' do
          before do
            shipments[0].ship
            shipments[1].ready
          end

          it { expect { shipments[1].ship }.to emit_webhook_event('order.shipped') }
        end

        context 'without all order shipments shipped' do
          it { expect { shipments[0].ship }.not_to emit_webhook_event('order.shipped') }
        end
      end

      context 'canceled -> ship' do
        before { shipments[0].cancel }

        context 'with all order shipments shipped' do
          before do
            shipments[0].ship
            shipments[1].cancel
          end

          it { expect { shipments[1].ship }.to emit_webhook_event('order.shipped') }
        end

        context 'without all order shipments shipped' do
          it { expect { shipments[0].ship }.not_to emit_webhook_event('order.shipped') }
        end
      end
    end
  end
end
