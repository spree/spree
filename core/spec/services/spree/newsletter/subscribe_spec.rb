require 'spec_helper'

module Spree
  describe Newsletter::Subscribe do
    subject(:service) { described_class.new(**params).call }

    let(:params) do
      {
        email: email,
        user: user
      }
    end

    let(:email) { 'foo@example.com' }
    let(:user) { nil }

    context 'when logged in user has the same email as inputed email' do
      let(:user) { create(:user) }
      let(:email) { user.email }

      it 'does not send a confirmation email' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:deliver_newsletter_subscription_confirmation)

        service
      end

      it 'creates a new verified subscriber' do
        expect { service }.to change { Spree::NewsletterSubscriber.verified.count }.by(1)
      end
    end

    context 'when logged in user inputs another email' do
      let(:user) { create(:user) }
      let(:email) { 'test@example.com' }

      it 'sends a confirmation email' do
        expect_any_instance_of(Spree::NewsletterSubscriber).to receive(:deliver_newsletter_subscription_confirmation)

        service
      end

      it 'creates a new unverified subscriber' do
        expect { service }.to change { Spree::NewsletterSubscriber.unverified.count }.by(1)
      end
    end

    context 'when verified subscription already exists' do
      let!(:subscriber) { create(:newsletter_subscriber, email: email, verified_at: Time.current) }

      it 'does not create new subscriber' do
        expect { service }.not_to change(Spree::NewsletterSubscriber, :count)
      end

      it 'does not regenerate verification token' do
        expect { service }.not_to change { subscriber.reload.verification_token }
      end

      it 'does not send a confirmation email' do
        expect(subscriber).not_to receive(:deliver_newsletter_subscription_confirmation)

        service
      end
    end

    context 'when unverified subscription has been already created' do
      let!(:subscriber) { create(:newsletter_subscriber, email: email, verified_at: nil) }

      it 'does not create new subscriber' do
        expect { service }.not_to change(Spree::NewsletterSubscriber, :count)
      end

      it 'regenerates verification token' do
        expect { service }.to change { subscriber.reload.verification_token }
      end

      it 'sends a confirmation email' do
        expect(subscriber).to receive(:deliver_newsletter_subscription_confirmation)

        service
      end
    end
  end
end
