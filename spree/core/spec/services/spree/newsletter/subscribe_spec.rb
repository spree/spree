require 'spec_helper'

module Spree
  describe Newsletter::Subscribe do
    subject(:service) { described_class.new(**params).call }

    let(:params) do
      {
        email: email,
        current_user: user,
        current_store: store,
        redirect_url: redirect_url
      }
    end

    let(:email) { 'foo@example.com' }
    let(:user) { nil }
    let(:store) { nil }
    let(:redirect_url) { nil }
    let(:default_store) { @default_store || create(:store) }

    before do
      allow(Spree::Current).to receive(:store).and_return(default_store)
    end

    context 'with invalid params' do
      let(:email) { 'hehe' }

      it 'returns a record with errors' do
        expect(service.errors).to be_present
      end

      it 'does not publish any subscription events' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:publish_event).with('newsletter_subscriber.subscription_requested', anything)

        service
      end

      it 'does not create a new record' do
        expect { service }.not_to change(Spree::NewsletterSubscriber, :count)
      end
    end

    context 'when logged in user has the same email as inputed email' do
      let(:user) { create(:user) }
      let(:email) { user.email }

      it 'returns an instance of NewsletterSubscriber' do
        expect(service).to be_a(NewsletterSubscriber)
      end

      it 'does not publish subscription_requested (auto-verified)' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:publish_event).with('newsletter_subscriber.subscription_requested', anything)

        service
      end

      it 'creates a new verified subscriber' do
        expect { service }.to change { Spree::NewsletterSubscriber.verified.count }.by(1)
      end
    end

    context 'when logged in user inputs another email' do
      let(:user) { create(:user) }
      let(:email) { 'test@example.com' }

      it 'publishes subscription_requested with the verification token' do
        published = nil
        allow_any_instance_of(Spree::NewsletterSubscriber).to receive(:publish_event) do |sub, name, payload = nil|
          published = { name: name, payload: payload } if name == 'newsletter_subscriber.subscription_requested'
        end

        service

        expect(published).to be_present
        expect(published[:payload][:email]).to eq('test@example.com')
        expect(published[:payload][:verification_token]).to be_present
        expect(published[:payload]).not_to have_key(:redirect_url)
      end

      it 'returns an instance of NewsletterSubscriber' do
        expect(service).to be_a(NewsletterSubscriber)
      end

      it 'creates a new unverified subscriber' do
        expect { service }.to change { Spree::NewsletterSubscriber.unverified.count }.by(1)
      end
    end

    context 'when a redirect_url is provided' do
      let(:redirect_url) { 'https://storefront.example.com/newsletter/confirm' }

      it 'forwards redirect_url in the subscription_requested payload' do
        published = nil
        allow_any_instance_of(Spree::NewsletterSubscriber).to receive(:publish_event) do |sub, name, payload = nil|
          published = payload if name == 'newsletter_subscriber.subscription_requested'
        end

        service

        expect(published[:redirect_url]).to eq(redirect_url)
      end
    end

    context 'when verified subscription already exists' do
      let!(:subscriber) { create(:newsletter_subscriber, :verified, email: email, store: default_store) }

      it 'returns an instance of NewsletterSubscriber' do
        expect(service).to be_a(NewsletterSubscriber)
      end

      it 'does not create new subscriber' do
        expect { service }.not_to change(Spree::NewsletterSubscriber, :count)
      end

      it 'does not publish any subscription events' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:publish_event).with('newsletter_subscriber.subscription_requested', anything)

        service
      end

      context 'when a logged in user matches the subscription email' do
        let(:user) { create(:user, email: email, accepts_email_marketing: false) }

        it 'links the existing subscriber to the user and preserves consent' do
          expect(service.user).to eq(user)
          expect(user.reload.accepts_email_marketing).to eq(true)
        end
      end
    end

    context 'when unverified subscription has been already created' do
      let!(:subscriber) { create(:newsletter_subscriber, :unverified, email: email, store: default_store) }

      it 'returns an instance of NewsletterSubscriber' do
        expect(service).to be_a(NewsletterSubscriber)
      end

      it 'does not create new subscriber' do
        expect { service }.not_to change(Spree::NewsletterSubscriber, :count)
      end

      it 'publishes the subscription_requested event so the email is re-dispatched' do
        expect_any_instance_of(Spree::NewsletterSubscriber).to receive(:publish_event).with('newsletter_subscriber.subscription_requested', anything).once

        service
      end

      context 'when a logged in user matches the subscription email' do
        let(:user) { create(:user, email: email, accepts_email_marketing: false) }

        it 'links and verifies the existing subscriber' do
          expect(service.user).to eq(user)
          expect(service.reload).to be_verified
          expect(user.reload.accepts_email_marketing).to eq(true)
        end
      end
    end

    context 'when subscription does not exist for given store' do
      it 'creates a new subscriber for the given store' do
        expect { service }.to change(Spree::NewsletterSubscriber, :count).by(1)
      end
    end

    context 'when subscription exists but for a different store' do
      let!(:subscriber) { create(:newsletter_subscriber, :verified, email: email, store: create(:store)) }

      it 'creates a new subscriber for the given store' do
        expect { service }.to change(Spree::NewsletterSubscriber, :count).by(1)
      end
    end
  end
end
