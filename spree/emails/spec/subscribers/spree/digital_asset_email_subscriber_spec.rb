# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::DigitalAssetEmailSubscriber do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { order.line_items.first }
  let(:subscriber) { described_class.new }

  def mock_event(order)
    double('Event', payload: { 'id' => order.prefixed_id })
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  context 'when the order has downloads' do
    before do
      digital_asset = create(:digital_asset, variant: line_item.variant)
      create(:digital_link, digital_asset: digital_asset, line_item: line_item)
    end

    it 'sends the files-ready email on order.placed' do
      expect(Spree::DigitalAssetMailer).to receive(:files_ready_email).
        with(order.id, false).and_return(double(deliver_later: true))

      subscriber.send(:send_files_ready_email, mock_event(order))
    end

    it 'marks a resend as such so the subject says so' do
      expect(Spree::DigitalAssetMailer).to receive(:files_ready_email).
        with(order.id, true).and_return(double(deliver_later: true))

      subscriber.send(:resend_files_ready_email, mock_event(order))
    end

    it 'stays quiet when the store suppresses consumer emails' do
      store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      expect(Spree::DigitalAssetMailer).not_to receive(:files_ready_email)

      subscriber.send(:send_files_ready_email, mock_event(order))
    end
  end

  context 'when the order has no downloads' do
    it 'sends nothing' do
      expect(Spree::DigitalAssetMailer).not_to receive(:files_ready_email)

      subscriber.send(:send_files_ready_email, mock_event(order))
    end
  end
end
