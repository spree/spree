require 'spec_helper'

module Spree
  describe Newsletter::Subscribe do
    subject(:service) { described_class.new(**params).call }

    let(:params) do
      {
        email: email,
        current_user: user
      }
    end

    let(:email) { 'foo@example.com' }
    let(:user) { nil }

    context 'with invalid params' do
      let(:email) { 'hehe' }

      it 'returns a record with errors' do
        expect(service.errors).to be_present
      end

      it 'does not send a confirmation email' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:publish_event).with('newsletter_subscriber.subscribed')

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

      it 'does not send a confirmation email' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:publish_event).with('newsletter_subscriber.subscribed')

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
        expect_any_instance_of(Spree::NewsletterSubscriber).to receive(:publish_event).with('newsletter_subscriber.subscribed').once

        service
      end

      it 'returns an instance of NewsletterSubscriber' do
        expect(service).to be_a(NewsletterSubscriber)
      end

      it 'creates a new unverified subscriber' do
        expect { service }.to change { Spree::NewsletterSubscriber.unverified.count }.by(1)
      end
    end

    context 'when verified subscription already exists' do
      let!(:subscriber) { create(:newsletter_subscriber, :verified, email: email) }

      it 'returns an instance of NewsletterSubscriber' do
        expect(service).to be_a(NewsletterSubscriber)
      end

      it 'does not create new subscriber' do
        expect { service }.not_to change(Spree::NewsletterSubscriber, :count)
      end

      it 'does not send a confirmation email' do
        expect_any_instance_of(Spree::NewsletterSubscriber).not_to receive(:publish_event).with('newsletter_subscriber.subscribed')

        service
      end
    end

    context 'when unverified subscription has been already created' do
      let!(:subscriber) { create(:newsletter_subscriber, :unverified, email: email) }

      it 'returns an instance of NewsletterSubscriber' do
        expect(service).to be_a(NewsletterSubscriber)
      end

      it 'does not create new subscriber' do
        expect { service }.not_to change(Spree::NewsletterSubscriber, :count)
      end

      it 'sends a confirmation email' do
        expect_any_instance_of(Spree::NewsletterSubscriber).to receive(:publish_event).with('newsletter_subscriber.subscribed').once

        service
      end
    end
  end
end
