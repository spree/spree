require 'spec_helper'

describe Spree::Shipment, type: :model do
  let(:order) { create(:order) }
  let(:shipping_method) { create(:shipping_method, name: 'UPS') }
  let(:shipment) { create(:shipment, cost: 1, state: 'pending', stock_location: create(:stock_location), order: order) }

  before do
    allow(order).to receive_messages backordered?: false,
                                     canceled?: false,
                                     can_ship?: true,
                                     paid?: false,
                                     touch_later: false

    allow(shipment).to receive_messages shipping_method: shipping_method
  end

  ['ready', 'canceled'].each do |state|
    context "from #{state}" do
      before do
        allow(order).to receive(:update_with_updater!)
        allow(shipment).to receive_messages(require_inventory: false, update_order: true, state: state)
      end

      it 'sends a shipment email' do
        mail_message = double 'Mail::Message'
        shipment_id = nil
        expect(Spree::ShipmentMailer).to receive(:shipped_email) { |*args|
          shipment_id = args[0]
          mail_message
        }
        expect(mail_message).to receive :deliver_later
        allow_any_instance_of(Spree::ShipmentHandler).to receive(:update_order_shipment_state)

        shipment.ship!
        expect(shipment_id).to eq(shipment.id)
      end

      context 'when send_consumer_transactional_emails store setting is set to false' do
        before do
          allow(shipment.store).to receive(:prefers_send_consumer_transactional_emails?).and_return(false)
        end

        it 'does not trigger the shipment mailer to be sent' do
          expect(Spree::ShipmentMailer).not_to receive(:shipped_email)
          shipment.ship!
        end
      end
    end
  end
end
