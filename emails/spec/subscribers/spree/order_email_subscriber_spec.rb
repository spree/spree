# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::OrderEmailSubscriber do
  include ActiveJob::TestHelper

  let(:store) { create(:store, new_order_notifications_email: 'store-owner@example.com') }
  let(:order) { create(:completed_order_with_totals, store: store) }

  def publish_event(event_name)
    perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
      Spree::Events.publish(
        event_name,
        { 'id' => order.id }
      )
    end
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
    Spree::Events.activate!
  end

  after { Spree::Events.reset! }

  describe 'order.complete event' do
    it 'sends confirmation email' do
      expect(Spree::OrderMailer).to receive(:confirm_email).with(order.id).and_return(double(deliver_later: true))
      allow(Spree::OrderMailer).to receive(:store_owner_notification_email).and_return(double(deliver_later: true))

      publish_event('order.complete')
    end

    it 'marks confirmation as delivered' do
      allow(Spree::OrderMailer).to receive(:confirm_email).and_return(double(deliver_later: true))
      allow(Spree::OrderMailer).to receive(:store_owner_notification_email).and_return(double(deliver_later: true))

      expect { publish_event('order.complete') }.to change { order.reload.confirmation_delivered }.from(false).to(true)
    end

    it 'sends store owner notification email' do
      allow(Spree::OrderMailer).to receive(:confirm_email).and_return(double(deliver_later: true))
      expect(Spree::OrderMailer).to receive(:store_owner_notification_email).with(order.id).and_return(double(deliver_later: true))

      publish_event('order.complete')
    end

    it 'marks store owner notification as delivered' do
      allow(Spree::OrderMailer).to receive(:confirm_email).and_return(double(deliver_later: true))
      allow(Spree::OrderMailer).to receive(:store_owner_notification_email).and_return(double(deliver_later: true))

      order.update_column(:store_owner_notification_delivered, false)
      expect { publish_event('order.complete') }.to change { order.reload.store_owner_notification_delivered }.from(false).to(true)
    end

    context 'when confirmation already delivered' do
      before { order.update_column(:confirmation_delivered, true) }

      it 'does not send confirmation email again' do
        expect(Spree::OrderMailer).not_to receive(:confirm_email)

        publish_event('order.complete')
      end
    end

    context 'when store does not prefer transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send confirmation email' do
        expect(Spree::OrderMailer).not_to receive(:confirm_email)

        publish_event('order.complete')
      end
    end

    context 'when store owner notification email is blank' do
      before { store.update!(new_order_notifications_email: nil) }

      it 'does not send store owner notification email' do
        allow(Spree::OrderMailer).to receive(:confirm_email).and_return(double(deliver_later: true))
        expect(Spree::OrderMailer).not_to receive(:store_owner_notification_email)

        publish_event('order.complete')
      end
    end

    context 'when order not found' do
      it 'does not raise an error' do
        order.destroy

        expect { publish_event('order.complete') }.not_to raise_error
      end
    end
  end

  describe 'order.cancel event' do
    it 'sends cancel email' do
      expect(Spree::OrderMailer).to receive(:cancel_email).with(order.id).and_return(double(deliver_later: true))

      publish_event('order.cancel')
    end

    context 'when order not found' do
      it 'does not raise an error' do
        order.destroy

        expect { publish_event('order.cancel') }.not_to raise_error
      end
    end
  end
end
