require 'spec_helper'

describe Spree::Api::Webhooks::ShipmentDecorator do
  let(:order) { create(:order) }
  let(:shipment) { create(:shipment) }

  describe '#after_ship' do
    before do
      # Avoid creating a new state change after transitioning as is defined in the model
      # because after_ship queues the HTTP request before finishing the transition, hence
      # the total state changes that are sent in the body is one less.
      allow(shipment).to receive_message_chain(:state_changes, :create!)

      # because state_changes is an instance of Double and can not be serialized
      allow_any_instance_of(Spree::Shipment).to receive(:included_relationships).and_return(Spree::Api::V2::Platform::ShipmentSerializer.relationships_to_serialize.keys - [:state_changes])
    end

    context 'emitting shipment.shipped' do
      let(:webhook_payload_body) do
        Spree::Api::V2::Platform::ShipmentSerializer.new(
          shipment,
          include: Spree::Api::V2::Platform::ShipmentSerializer.relationships_to_serialize.keys - [:state_changes]
        ).serializable_hash
      end
      let(:event_name) { 'shipment.shipped' }
      let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }

      context 'ready -> ship' do
        let(:shipment) { create(:shipment, order: order) }

        before do
          order.update(state: 'complete', completed_at: Time.current)
          shipment.reload
          shipment.ready
        end

        it { expect { shipment.ship }.to emit_webhook_event(event_name) }
      end

      context 'canceled -> ship' do
        before { shipment.cancel }

        it { expect { shipment.ship }.to emit_webhook_event(event_name) }
      end
    end

    context 'emitting order.shipped' do
      let(:webhook_payload_body) do
        webhook_payload_body = Spree::Api::V2::Platform::OrderSerializer.new(
          order.reload,
          include: Spree::Api::V2::Platform::OrderSerializer.relationships_to_serialize.keys
        ).serializable_hash
        webhook_payload_body[:included].each { |resource_hash| resource_hash[:relationships][:state_changes][:data] = [] if resource_hash[:type] == :shipment }
        webhook_payload_body
      end
      let(:event_name) { 'order.shipped' }
      let!(:webhook_subscriber) { create(:webhook_subscriber, :active, subscriptions: [event_name]) }
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
            shipments.each { |s| s.state_changes.destroy_all }
          end

          it do
            expect { shipments[1].ship }.to emit_webhook_event(event_name)
          end
        end

        context 'without all order shipments shipped' do
          it { expect { shipments[0].ship }.not_to emit_webhook_event(event_name) }
        end
      end

      context 'canceled -> ship' do
        before { shipments[0].cancel }

        context 'with all order shipments shipped' do
          before do
            shipments[0].ship
            shipments[1].cancel
            shipments.each { |s| s.state_changes.destroy_all }
          end

          it { expect { shipments[1].ship }.to emit_webhook_event(event_name) }
        end

        context 'without all order shipments shipped' do
          it { expect { shipments[0].ship }.not_to emit_webhook_event(event_name) }
        end
      end
    end
  end
end
