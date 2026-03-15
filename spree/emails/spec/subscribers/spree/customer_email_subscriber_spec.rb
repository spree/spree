# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::CustomerEmailSubscriber do
  let(:store) { create(:store) }
  let(:user) { create(:user, email: 'customer@example.com') }
  let(:subscriber) { described_class.new }
  let(:reset_token) { 'test-reset-token-123' }
  let(:redirect_url) { 'https://mystore.com/reset-password' }

  def mock_event(payload = {}, store_id: store.id)
    double('Event',
      payload: payload.deep_stringify_keys,
      store_id: store_id
    )
  end

  before do
    store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: true))
  end

  describe 'customer.password_reset_requested event' do
    let(:event) do
      mock_event(
        { email: user.email, reset_token: reset_token, redirect_url: redirect_url },
        store_id: store.id
      )
    end

    it 'sends password reset email' do
      expect(Spree::CustomerMailer).to receive(:password_reset_email)
        .with(user.id, store.id, reset_token, redirect_url)
        .and_return(double(deliver_later: true))

      subscriber.handle(event)
    end

    it 'passes nil redirect_url when not in payload' do
      event_without_redirect = mock_event(
        { email: user.email, reset_token: reset_token },
        store_id: store.id
      )

      expect(Spree::CustomerMailer).to receive(:password_reset_email)
        .with(user.id, store.id, reset_token, nil)
        .and_return(double(deliver_later: true))

      subscriber.handle(event_without_redirect)
    end

    context 'when store disables transactional emails' do
      before do
        store.update!(preferences: store.preferences.merge(send_consumer_transactional_emails: false))
      end

      it 'does not send email' do
        expect(Spree::CustomerMailer).not_to receive(:password_reset_email)

        subscriber.handle(event)
      end
    end

    context 'when email is blank' do
      let(:event) { mock_event({ email: '', reset_token: reset_token }, store_id: store.id) }

      it 'does not send email' do
        expect(Spree::CustomerMailer).not_to receive(:password_reset_email)

        subscriber.handle(event)
      end
    end

    context 'when email is nil' do
      let(:event) { mock_event({ reset_token: reset_token }, store_id: store.id) }

      it 'does not send email' do
        expect(Spree::CustomerMailer).not_to receive(:password_reset_email)

        subscriber.handle(event)
      end
    end

    context 'when user is not found' do
      let(:event) do
        mock_event(
          { email: 'nonexistent@example.com', reset_token: reset_token },
          store_id: store.id
        )
      end

      it 'does not send email' do
        expect(Spree::CustomerMailer).not_to receive(:password_reset_email)

        subscriber.handle(event)
      end
    end

    context 'when store_id is nil' do
      let(:event) do
        mock_event(
          { email: user.email, reset_token: reset_token, redirect_url: redirect_url },
          store_id: nil
        )
      end

      it 'falls back to current store' do
        allow(Spree::Current).to receive(:store).and_return(store)

        expect(Spree::CustomerMailer).to receive(:password_reset_email)
          .with(user.id, store.id, reset_token, redirect_url)
          .and_return(double(deliver_later: true))

        subscriber.handle(event)
      end
    end
  end
end
