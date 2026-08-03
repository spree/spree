# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::FulfillmentEmailSubscriber do
  let(:store) { create(:store) }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:fulfillment) { order.fulfillments.first }
  let(:subscriber) { described_class.new }

  def mock_event(fulfillment)
    double('Event', payload: { 'id' => fulfillment.prefixed_id })
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  describe 'fulfillment.fulfilled event' do
    it 'sends the fulfilled email' do
      expect(Spree::FulfillmentMailer).to receive(:fulfilled_email).with(fulfillment.id).and_return(double(deliver_later: true))

      subscriber.handle(mock_event(fulfillment))
    end

    context 'when store does not prefer transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send the fulfilled email' do
        expect(Spree::FulfillmentMailer).not_to receive(:fulfilled_email)

        subscriber.handle(mock_event(fulfillment))
      end
    end

    context 'when fulfillment not found' do
      it 'does not raise an error' do
        fulfillment.destroy

        expect { subscriber.handle(mock_event(fulfillment)) }.not_to raise_error
      end
    end
  end
end
