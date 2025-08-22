require 'spec_helper'

describe Spree::Order, type: :model do
  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, store: store) }

  context '#finalize!' do
    let(:order) { create(:order, email: 'test@example.com', store: store) }

    before do
      order.update_column :state, 'complete'
    end

    it 'sends an order confirmation email to customer' do
      mail_message = double 'Mail::Message'
      expect(Spree::OrderMailer).to receive(:confirm_email).with(order.id).and_return mail_message
      expect(mail_message).to receive :deliver_later
      order.finalize!
    end

    context 'when send_consumer_transactional_emails store setting is set to false' do
      before do
        allow(order.store).to receive(:prefers_send_consumer_transactional_emails?).and_return(false)
      end

      it 'does not send order confirmation email to customer' do
        expect(Spree::OrderMailer).not_to receive(:confirm_email)
        order.finalize!
      end
    end

    it 'sets confirmation delivered when finalizing' do
      expect(order.confirmation_delivered?).to be false
      order.finalize!
      expect(order.confirmation_delivered?).to be true
    end

    it 'does not send duplicate confirmation emails' do
      allow(order).to receive_messages(confirmation_delivered?: true)
      expect(Spree::OrderMailer).not_to receive(:confirm_email)
      order.finalize!
    end

    context 'new order notifications' do
      it 'sends a new order notification email to store owner when notification email address is set' do
        mail_message = double 'Mail::Message'
        allow(store).to receive(:new_order_notifications_email).and_return('test@example.com')
        expect(Spree::OrderMailer).to receive(:store_owner_notification_email).with(order.id).and_return mail_message
        expect(mail_message).to receive :deliver_later
        order.finalize!
      end

      it 'does not send a new order notification email to store owner when notification email address is blank' do
        allow(store).to receive(:new_order_notifications_email).and_return(nil)

        mail_message = double 'Mail::Message'
        expect(Spree::OrderMailer).to_not receive(:store_owner_notification_email)
        order.finalize!
      end
    end
  end

  describe '#deliver_order_confirmation_email' do
    let(:order) { create(:completed_order_with_totals, email: 'test@example.com', store: store) }

    context 'when send_consumer_transactional_emails store setting is enabled' do
      before do
        allow(order.store).to receive(:prefers_send_consumer_transactional_emails?).and_return(true)
      end

      it 'sends order confirmation email' do
        mail_message = double 'Mail::Message'
        expect(Spree::OrderMailer).to receive(:confirm_email).with(order.id).and_return(mail_message)
        expect(mail_message).to receive(:deliver_later)
        order.deliver_order_confirmation_email
      end
    end

    context 'when send_consumer_transactional_emails store setting is disabled' do
      before do
        allow(order.store).to receive(:prefers_send_consumer_transactional_emails?).and_return(false)
      end

      it 'does not send order confirmation email' do
        expect(Spree::OrderMailer).not_to receive(:confirm_email)
        order.deliver_order_confirmation_email
      end

      it 'still sets confirmation_delivered to true' do
        expect(order.confirmation_delivered?).to be false
        order.deliver_order_confirmation_email
        expect(order.confirmation_delivered?).to be true
      end
    end
  end

  describe '#cancel' do
    let(:order) { build(:order) }
    let!(:variant) { create(:variant) }
    let!(:inventory_units) { create_list(:inventory_unit, 2, variant: variant) }
    let!(:shipment) { create(:shipment) }
    let!(:line_items) { create_list(:line_item, 2, order: order, price: 10) }

    before do
      allow(shipment).to receive_messages inventory_units: inventory_units, order: order
      allow(order).to receive_messages shipments: [shipment]

      allow(order.line_items).to receive(:find_by).with(hash_including(:variant_id)) { line_items.first }

      allow(order).to receive_messages completed?: true
      allow(order).to receive_messages allow_cancel?: true

      shipments = [shipment]
      allow(order).to receive_messages shipments: shipments
      allow(shipments).to receive_messages states: []
      allow(shipments).to receive_messages ready: []
      allow(shipments).to receive_messages pending: []
      allow(shipments).to receive_messages shipped: []
      allow(shipments).to receive_message_chain(:sum, :cost).and_return(shipment.cost)

      allow_any_instance_of(Spree::OrderUpdater).to receive(:update_adjustment_total).and_return(10)
    end

    it 'sends a cancel email' do
      # Stub methods that cause side-effects in this test
      allow(shipment).to receive(:cancel!)
      allow(order).to receive :restock_items!
      mail_message = double 'Mail::Message'
      order_id = nil
      expect(Spree::OrderMailer).to receive(:cancel_email) { |*args|
        order_id = args[0]
        mail_message
      }
      expect(mail_message).to receive :deliver_later
      order.cancel!
      expect(order_id).to eq(order.id)
    end
  end
end
