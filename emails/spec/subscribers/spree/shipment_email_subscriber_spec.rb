# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ShipmentEmailSubscriber do
  include ActiveJob::TestHelper

  let(:store) { create(:store) }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:shipment) { order.shipments.first }

  def publish_event(event_name)
    perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
      Spree::Events.publish(
        event_name,
        { 'id' => shipment.id }
      )
    end
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
    # Unregister first to avoid duplicate subscriptions from engine initialization
    described_class.unregister!
    described_class.register!
  end

  after do
    described_class.unregister!
  end

  describe 'shipment.ship event' do
    it 'sends shipped email' do
      expect(Spree::ShipmentMailer).to receive(:shipped_email).with(shipment.id).and_return(double(deliver_later: true))

      publish_event('shipment.ship')
    end

    context 'when store does not prefer transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send shipped email' do
        expect(Spree::ShipmentMailer).not_to receive(:shipped_email)

        publish_event('shipment.ship')
      end
    end

    context 'when shipment not found' do
      it 'does not raise an error' do
        shipment.destroy

        expect { publish_event('shipment.ship') }.not_to raise_error
      end
    end
  end
end
