# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::ShipmentEmailSubscriber do
  let(:store) { create(:store) }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:shipment) { order.shipments.first }
  let(:subscriber) { described_class.new }

  def mock_event(shipment)
    double('Event', payload: { 'id' => shipment.id })
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  describe 'shipment.shipped event' do
    it 'sends shipped email' do
      expect(Spree::ShipmentMailer).to receive(:shipped_email).with(shipment.id).and_return(double(deliver_later: true))

      subscriber.handle(mock_event(shipment))
    end

    context 'when store does not prefer transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send shipped email' do
        expect(Spree::ShipmentMailer).not_to receive(:shipped_email)

        subscriber.handle(mock_event(shipment))
      end
    end

    context 'when shipment not found' do
      it 'does not raise an error' do
        shipment.destroy

        expect { subscriber.handle(mock_event(shipment)) }.not_to raise_error
      end
    end
  end
end
