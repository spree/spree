# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::CustomerEmailSubscriber do
  let(:store) { @default_store }
  let(:user) { create(:user, email: 'customer@example.com') }
  let(:subscriber) { described_class.new }

  def mock_event(email:, redirect_url: nil, store_id: store.prefixed_id)
    payload = { 'email' => email, 'reset_token' => 'secret-reset-token', 'store_id' => store_id }
    payload['redirect_url'] = redirect_url if redirect_url
    double('Event', payload: payload)
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  describe 'customer.password_reset_requested event' do
    it 'sends the password reset email' do
      expect(Spree::CustomerMailer).to receive(:password_reset_email).
        with(user, 'secret-reset-token', store, redirect_url: nil).
        and_return(double(deliver_later: true))

      subscriber.handle(mock_event(email: user.email))
    end

    it 'forwards the redirect URL from the event payload' do
      expect(Spree::CustomerMailer).to receive(:password_reset_email).
        with(user, 'secret-reset-token', store, redirect_url: 'https://storefront.example.com/reset').
        and_return(double(deliver_later: true))

      subscriber.handle(mock_event(email: user.email, redirect_url: 'https://storefront.example.com/reset'))
    end

    it 'does nothing when no user matches the email' do
      expect(Spree::CustomerMailer).not_to receive(:password_reset_email)

      subscriber.handle(mock_event(email: 'unknown@example.com'))
    end

    it 'does nothing when the store disabled consumer transactional emails' do
      store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))

      expect(Spree::CustomerMailer).not_to receive(:password_reset_email)

      subscriber.handle(mock_event(email: user.email))
    end
  end
end
