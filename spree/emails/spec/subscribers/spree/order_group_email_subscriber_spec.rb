# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::OrderGroupEmailSubscriber do
  let(:store) { create(:store, new_order_notifications_email: 'store-owner@example.com') }
  let(:group) { create(:order_group, store: store) }
  let(:subscriber) { described_class.new }

  def mock_event(order_group)
    double('Event', payload: { 'id' => order_group.prefixed_id })
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
    allow(Spree::OrderGroupMailer).to receive(:store_owner_notification_email).
      and_return(double(deliver_later: true))
  end

  describe 'order_group.completed' do
    it 'confirms the purchase' do
      expect(Spree::OrderGroupMailer).to receive(:confirm_email).with(group.id).
        and_return(double(deliver_later: true))

      subscriber.send(:send_confirmation_email, mock_event(group))
    end

    it 'records that it did' do
      allow(Spree::OrderGroupMailer).to receive(:confirm_email).and_return(double(deliver_later: true))

      expect { subscriber.send(:send_confirmation_email, mock_event(group)) }.
        to change { group.reload.confirmation_delivered }.from(false).to(true)
    end

    # Completion is replayable, and a resumed finalize re-publishes the event.
    it 'does not confirm a purchase twice' do
      group.update_column(:confirmation_delivered, true)

      expect(Spree::OrderGroupMailer).not_to receive(:confirm_email)

      subscriber.send(:send_confirmation_email, mock_event(group))
    end

    # Matches the single-order subscriber: turning customer receipts off must
    # not stop the store hearing about its own sales (spree/spree#14724).
    it 'still tells the store when customer receipts are switched off' do
      store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))

      expect(Spree::OrderGroupMailer).not_to receive(:confirm_email)
      expect(Spree::OrderGroupMailer).to receive(:store_owner_notification_email).
        and_return(double(deliver_later: true))

      subscriber.send(:send_confirmation_email, mock_event(group))
    end

    # An operator completing a draft quietly says so on the group event, which
    # is the only thing that reaches this subscriber. It silences the customer
    # and not the store, which is a different audience.
    it 'does not confirm the customer when the completion asked to stay silent' do
      expect(Spree::OrderGroupMailer).not_to receive(:confirm_email)
      expect(Spree::OrderGroupMailer).to receive(:store_owner_notification_email).
        and_return(double(deliver_later: true))

      subscriber.send(:send_confirmation_email,
                      double('Event', payload: { 'id' => group.prefixed_id, 'notify_customer' => false }))
    end

    it 'ignores a group it cannot find' do
      expect(Spree::OrderGroupMailer).not_to receive(:confirm_email)

      subscriber.send(:send_confirmation_email, double('Event', payload: { 'id' => 'ogrp_missing' }))
    end

    describe 'the store owner' do
      before { allow(Spree::OrderGroupMailer).to receive(:confirm_email).and_return(double(deliver_later: true)) }

      # One notification per purchase, like the customer's — it used to ride
      # inside the first child order's confirmation.
      it 'is told about the purchase once' do
        expect(Spree::OrderGroupMailer).to receive(:store_owner_notification_email).with(group.id).
          and_return(double(deliver_later: true))

        expect { subscriber.send(:send_confirmation_email, mock_event(group)) }.
          to change { group.reload.store_owner_notification_delivered }.from(false).to(true)
      end

      it 'is left alone when the store nominated no address' do
        store.update!(new_order_notifications_email: nil)

        expect(Spree::OrderGroupMailer).not_to receive(:store_owner_notification_email)

        subscriber.send(:send_confirmation_email, mock_event(group))
      end

      # A replay that gets as far as stamping the customer's flag and no
      # further still owes the operator their notification.
      it 'is still told when a replay finds the customer already confirmed' do
        group.update_column(:confirmation_delivered, true)

        expect(Spree::OrderGroupMailer).not_to receive(:confirm_email)
        expect(Spree::OrderGroupMailer).to receive(:store_owner_notification_email).with(group.id).
          and_return(double(deliver_later: true))

        expect { subscriber.send(:send_confirmation_email, mock_event(group)) }.
          to change { group.reload.store_owner_notification_delivered }.from(false).to(true)
      end

      it 'is not told twice' do
        group.update_column(:store_owner_notification_delivered, true)

        expect(Spree::OrderGroupMailer).not_to receive(:store_owner_notification_email)

        subscriber.send(:send_confirmation_email, mock_event(group))
      end
    end
  end

  describe 'order_group.resend_confirmation_email' do
    it 'sends the purchase confirmation again, marked as a re-send' do
      expect(Spree::OrderGroupMailer).to receive(:confirm_email).with(group.id, true).
        and_return(double(deliver_later: true))

      subscriber.send(:resend_confirmation_email, mock_event(group))
    end

    it 'resends even though the first one was delivered' do
      group.update_column(:confirmation_delivered, true)

      expect(Spree::OrderGroupMailer).to receive(:confirm_email).and_return(double(deliver_later: true))

      subscriber.send(:resend_confirmation_email, mock_event(group))
    end
  end
end
