# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::AdminUserEmailSubscriber do
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user, email: 'admin@example.com') }
  let(:subscriber) { described_class.new }

  def mock_event(email:, redirect_url: nil, store_id: store.prefixed_id)
    payload = { 'email' => email, 'reset_token' => 'secret-reset-token', 'store_id' => store_id }
    payload['redirect_url'] = redirect_url if redirect_url
    double('Event', payload: payload)
  end

  describe 'admin_user.password_reset_requested event' do
    it 'sends the password reset email' do
      expect(Spree::AdminUserMailer).to receive(:password_reset_email).
        with(admin_user, 'secret-reset-token', store, redirect_url: nil).
        and_return(double(deliver_later: true))

      subscriber.handle(mock_event(email: admin_user.email))
    end

    it 'forwards the redirect URL from the event payload' do
      expect(Spree::AdminUserMailer).to receive(:password_reset_email).
        with(admin_user, 'secret-reset-token', store, redirect_url: 'https://admin.example.com/reset').
        and_return(double(deliver_later: true))

      subscriber.handle(mock_event(email: admin_user.email, redirect_url: 'https://admin.example.com/reset'))
    end

    it 'does nothing when no admin user matches the email' do
      expect(Spree::AdminUserMailer).not_to receive(:password_reset_email)

      subscriber.handle(mock_event(email: 'unknown@example.com'))
    end
  end
end
