# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::DataRequestEmailSubscriber do
  let(:store) { @default_store }
  let(:customer) { create(:user, email: 'customer@example.com') }
  let(:subscriber) { described_class.new }

  def mock_event(record)
    double('Event', payload: { 'id' => record.prefixed_id })
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  describe 'a finished access request' do
    let(:data_request) { create(:data_request, store: store, customer: customer) }

    before { Spree::DataRequests::Fulfill.call(data_request: data_request) }

    it 'emails the download link to the person who asked' do
      expect(Spree::CustomerMailer).to receive(:data_export_email).
        with(data_request).and_return(double(deliver_later: true))

      subscriber.handle(mock_event(data_request.reload))
    end
  end

  # The account's address has just been replaced with an undeliverable one, and
  # writing to the old address would re-record the very detail the request
  # asked to remove.
  describe 'a finished erasure request' do
    let(:data_request) { create(:data_request, :erasure, store: store, customer: customer) }

    before { Spree::DataRequests::Fulfill.call(data_request: data_request) }

    it 'sends nothing' do
      expect(Spree::CustomerMailer).not_to receive(:data_export_email)

      subscriber.handle(mock_event(data_request.reload))
    end
  end

  describe 'a request whose export has expired' do
    let(:data_request) { create(:data_request, store: store, customer: customer) }

    before do
      Spree::DataRequests::Fulfill.call(data_request: data_request)
      data_request.reload.update!(expires_at: 1.day.ago)
    end

    it 'sends nothing, because the link would not work' do
      expect(Spree::CustomerMailer).not_to receive(:data_export_email)

      subscriber.handle(mock_event(data_request))
    end
  end

  describe 'a store that does not send customer email' do
    let(:data_request) { create(:data_request, store: store, customer: customer) }

    before do
      Spree::DataRequests::Fulfill.call(data_request: data_request)
      store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
    end

    it 'respects the setting' do
      expect(Spree::CustomerMailer).not_to receive(:data_export_email)

      subscriber.handle(mock_event(data_request.reload))
    end
  end
end
