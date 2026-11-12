# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::DataRequestConfirmationEmailSubscriber do
  let(:store) { @default_store }
  let(:customer) { create(:user, email: 'customer@example.com') }
  let(:subscriber) { described_class.new }
  let(:data_request) { create(:data_request, :awaiting_confirmation, store: store, customer: customer) }

  def mock_event(record, redirect_url: nil)
    double('Event', payload: { 'id' => record.prefixed_id, 'confirmation_token' => 'live-token',
                               'redirect_url' => redirect_url })
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  it 'emails the confirmation link to the address the request names' do
    expect(Spree::CustomerMailer).to receive(:data_request_confirmation_email).
      with(data_request, 'live-token', redirect_url: 'https://shop.example.com/confirm').
      and_return(double(deliver_later: true))

    subscriber.handle(mock_event(data_request, redirect_url: 'https://shop.example.com/confirm'))
  end

  it 'sends nothing once the request has been confirmed' do
    data_request.update!(status: 'pending')

    expect(Spree::CustomerMailer).not_to receive(:data_request_confirmation_email)

    subscriber.handle(mock_event(data_request))
  end

  it 'respects a store that does not send customer email' do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))

    expect(Spree::CustomerMailer).not_to receive(:data_request_confirmation_email)

    subscriber.handle(mock_event(data_request))
  end

  describe 'through the registered subscribers', events: true do
    it 'emails the link when a customer opens a request' do
      perform_enqueued_jobs do
        expect {
          Spree::DataRequests::Create.call(store: store, customer: customer, kind: Spree::DataRequest::ACCESS,
                                           confirm_by_email: true)
        }.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      message = ActionMailer::Base.deliveries.last
      expect(message.to).to eq(['customer@example.com'])
      expect(message.html_part.decoded).to include('token=')
    end
  end
end
