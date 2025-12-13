require 'spec_helper'

describe Spree::Order, type: :model do
  include ActiveJob::TestHelper

  let(:store) { @default_store }
  let(:user) { create(:user) }
  let(:order) { create(:order, user: user, store: store) }

  before { Spree::Events.activate! }
  after { Spree::Events.reset! }

  context '#finalize!' do
    let(:order) { create(:order, email: 'test@example.com', store: store) }

    before do
      order.update_column :state, 'complete'
    end

    it 'sends an order confirmation email to customer via subscriber' do
      mail_message = double 'Mail::Message'
      expect(Spree::OrderMailer).to receive(:confirm_email).with(order.id).and_return mail_message
      expect(mail_message).to receive :deliver_later

      perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
        order.finalize!
      end
    end

    context 'when send_consumer_transactional_emails store setting is set to false' do
      before do
        # Update store preferences in DB since subscriber reloads order
        order.store.update!(preferences: order.store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send order confirmation email to customer' do
        expect(Spree::OrderMailer).not_to receive(:confirm_email)

        perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
          order.finalize!
        end
      end
    end

    it 'sets confirmation delivered when finalizing via subscriber' do
      allow(Spree::OrderMailer).to receive(:confirm_email).and_return(double(deliver_later: true))
      allow(Spree::OrderMailer).to receive(:store_owner_notification_email).and_return(double(deliver_later: true))

      expect(order.confirmation_delivered?).to be false

      perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
        order.finalize!
      end

      expect(order.reload.confirmation_delivered?).to be true
    end

    it 'does not send duplicate confirmation emails' do
      order.update_column(:confirmation_delivered, true)
      expect(Spree::OrderMailer).not_to receive(:confirm_email)

      perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
        order.finalize!
      end
    end

    context 'new order notifications' do
      it 'sends a new order notification email to store owner when notification email address is set' do
        mail_message = double 'Mail::Message'
        allow(Spree::OrderMailer).to receive(:confirm_email).and_return(double(deliver_later: true))
        # Update store in DB since subscriber reloads order
        store.update!(new_order_notifications_email: 'test@example.com')
        expect(Spree::OrderMailer).to receive(:store_owner_notification_email).with(order.id).and_return mail_message
        expect(mail_message).to receive :deliver_later

        perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
          order.finalize!
        end
      end

      it 'does not send a new order notification email to store owner when notification email address is blank' do
        allow(Spree::OrderMailer).to receive(:confirm_email).and_return(double(deliver_later: true))
        # Update store in DB since subscriber reloads order
        store.update!(new_order_notifications_email: nil)

        expect(Spree::OrderMailer).to_not receive(:store_owner_notification_email)

        perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
          order.finalize!
        end
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

    it 'sends a cancel email via subscriber' do
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

      perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
        order.cancel!
      end

      expect(order_id).to eq(order.id)
    end
  end
end
