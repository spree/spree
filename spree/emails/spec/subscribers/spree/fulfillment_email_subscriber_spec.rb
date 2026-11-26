# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::FulfillmentEmailSubscriber do
  let(:store) { create(:store) }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:fulfillment) { order.fulfillments.first }
  let(:subscriber) { described_class.new }

  def mock_event(fulfillment, name = 'fulfillment.fulfilled', **metadata)
    double('Event', name: name, payload: { 'id' => fulfillment.prefixed_id }, metadata: metadata.stringify_keys)
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  describe 'fulfillment.fulfilled event' do
    it 'sends the fulfilled email' do
      expect(Spree::FulfillmentMailer).to receive(:fulfilled_email).with(fulfillment.id).and_return(double(deliver_later: true))

      subscriber.call(mock_event(fulfillment))
    end

    context 'when store does not prefer transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send the fulfilled email' do
        expect(Spree::FulfillmentMailer).not_to receive(:fulfilled_email)

        subscriber.call(mock_event(fulfillment))
      end
    end

    context 'when fulfillment not found' do
      it 'does not raise an error' do
        fulfillment.destroy

        expect { subscriber.call(mock_event(fulfillment)) }.not_to raise_error
      end
    end

    # An admin shipping from the backoffice can suppress the email for one
    # dispatch — a correction, a re-ship, or goods handed over in person.
    context 'when the event suppresses the notification' do
      it 'does not send the fulfilled email' do
        expect(Spree::FulfillmentMailer).not_to receive(:fulfilled_email)

        subscriber.call(mock_event(fulfillment, notify_customer: false))
      end
    end

    context 'when the event asks for the notification' do
      it 'sends the fulfilled email' do
        expect(Spree::FulfillmentMailer).to receive(:fulfilled_email).with(fulfillment.id).and_return(double(deliver_later: true))

        subscriber.call(mock_event(fulfillment, notify_customer: true))
      end
    end
  end

  describe 'fulfillment.delivered event' do
    def mock_event(fulfillment, **metadata)
      super(fulfillment, 'fulfillment.delivered', **metadata)
    end

    def select_delivery_method(delivery_method)
      fulfillment.delivery_rates.update_all(selected: false)
      fulfillment.delivery_rates.create!(delivery_method: delivery_method, cost: 0, selected: true)
    end

    it 'sends the delivered email' do
      expect(Spree::FulfillmentMailer).to receive(:delivered_email).with(fulfillment.id).and_return(double(deliver_later: true))

      subscriber.call(mock_event(fulfillment))
    end

    it 'does not send the fulfilled email' do
      allow(Spree::FulfillmentMailer).to receive(:delivered_email).and_return(double(deliver_later: true))
      expect(Spree::FulfillmentMailer).not_to receive(:fulfilled_email)

      subscriber.call(mock_event(fulfillment))
    end

    it 'does not send when the event suppresses the notification' do
      expect(Spree::FulfillmentMailer).not_to receive(:delivered_email)

      subscriber.call(mock_event(fulfillment, notify_customer: false))
    end

    it 'does not send when the store does not prefer transactional emails' do
      store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      expect(Spree::FulfillmentMailer).not_to receive(:delivered_email)

      subscriber.call(mock_event(fulfillment))
    end

    it 'does not send for an order the customer collected in store' do
      select_delivery_method(create(:pickup_delivery_method))
      expect(Spree::FulfillmentMailer).not_to receive(:delivered_email)

      subscriber.call(mock_event(fulfillment))
    end

    it 'does not send for a digital fulfillment' do
      select_delivery_method(create(:digital_delivery_method))
      expect(Spree::FulfillmentMailer).not_to receive(:delivered_email)

      subscriber.call(mock_event(fulfillment))
    end

    it 'sends for a parcel delivered to a pickup point' do
      select_delivery_method(create(:pickup_point_delivery_method))
      expect(Spree::FulfillmentMailer).to receive(:delivered_email).with(fulfillment.id).and_return(double(deliver_later: true))

      subscriber.call(mock_event(fulfillment))
    end
  end

  # The whole path, from the workflow a carrier or staff member triggers.
  describe 'marking a fulfillment delivered', events: true do
    let(:order) { create(:shipped_order, store: store) }

    it 'emails the customer' do
      perform_enqueued_jobs do
        expect { Spree::Fulfillments::MarkDelivered.call(fulfillment: fulfillment) }.
          to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq([order.email])
      expect(mail.subject).to include('Your order has been delivered')
    end

    it 'stays quiet when staff ask it to' do
      perform_enqueued_jobs do
        expect { Spree::Fulfillments::MarkDelivered.call(fulfillment: fulfillment, notify_customer: false) }.
          not_to(change { ActionMailer::Base.deliveries.count })
      end
    end
  end
end
