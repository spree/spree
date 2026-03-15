require 'spec_helper'
require 'email_spec'

describe Spree::CustomerMailer, type: :mailer do
  include EmailSpec::Helpers
  include EmailSpec::Matchers

  let!(:store) { @default_store }
  let(:user) { create(:user, email: 'customer@example.com', first_name: 'Jane') }
  let(:reset_token) { 'test-reset-token-123' }
  let(:redirect_url) { 'https://mystore.com/reset-password' }

  describe '#password_reset_email' do
    context 'with redirect_url' do
      let(:email) { described_class.password_reset_email(user.id, store.id, reset_token, redirect_url) }

      it 'sends to the correct email address' do
        expect(email.to).to eq(['customer@example.com'])
      end

      it 'has correct subject with store name' do
        expect(email.subject).to eq("#{store.name} Password Reset")
      end

      it 'uses store from_address' do
        expect(email.from).to eq([store.mail_from_address])
      end

      it 'uses store reply_to address' do
        expect(email.reply_to).to eq([store.mail_from_address])
      end

      it 'includes reset URL with token' do
        expect(email).to have_body_text('https://mystore.com/reset-password?token=test-reset-token-123')
      end

      it 'includes the Reset Password button text' do
        expect(email).to have_body_text('Reset Password')
      end

      it 'includes greeting with user first name' do
        expect(email).to have_body_text('Hi Jane,')
      end

      it 'includes store team sign-off' do
        expect(email).to have_body_text("#{store.name} Team")
      end
    end

    context 'with redirect_url that has existing query params' do
      let(:redirect_url_with_params) { 'https://mystore.com/reset-password?locale=en' }
      let(:email) { described_class.password_reset_email(user.id, store.id, reset_token, redirect_url_with_params) }

      it 'appends token to existing query params' do
        expect(email).to have_body_text('https://mystore.com/reset-password?locale=en&token=test-reset-token-123')
      end
    end

    context 'without redirect_url' do
      let(:email) { described_class.password_reset_email(user.id, store.id, reset_token, nil) }

      it 'does not include a reset URL link' do
        expect(email).not_to have_body_text('mystore.com/reset-password')
      end

      it 'does not render the reset button' do
        expect(email).not_to have_body_text('Reset Password')
      end

      it 'still sends the email successfully' do
        expect(email.to).to eq(['customer@example.com'])
      end
    end

    context 'when user has no first name' do
      let(:user_no_name) { create(:user, email: 'anon@example.com', first_name: nil) }
      let(:email) { described_class.password_reset_email(user_no_name.id, store.id, reset_token, redirect_url) }

      it 'uses email in greeting' do
        expect(email).to have_body_text('Hi anon@example.com,')
      end
    end

    context 'with preference :send_core_emails set to false' do
      it 'sends no email' do
        Spree::Config.set(:send_core_emails, false)
        message = described_class.password_reset_email(user.id, store.id, reset_token, redirect_url)
        expect(message.body).to be_blank
      end
    end
  end
end
