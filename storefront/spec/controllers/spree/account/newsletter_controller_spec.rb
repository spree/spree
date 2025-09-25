require 'spec_helper'

RSpec.describe Spree::Account::NewsletterController, type: :controller, newsletter: true do
  let(:store) { @default_store }
  let(:user) { create(:user, email: 'test@example.com') }

  render_views

  before do
    allow(controller).to receive_messages(current_store: store, try_spree_current_user: user)
  end

  describe 'GET #edit' do
    subject { get :edit }

    it 'renders the edit template' do
      subject
      expect(response).to render_template(:edit)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PUT #update' do
    subject { put :update, params: { user: { accepts_email_marketing: accepts_email_marketing } } }

    context 'when user subscribes to the newsletter' do
      let(:accepts_email_marketing) { true }

      it 'tracks the subscribed_to_newsletter event' do
        expect(controller).to receive(:track_event).with('subscribed_to_newsletter', { email: 'test@example.com', user: user })
        subject

        expect(response).to have_http_status(:ok)
        expect(user.reload.accepts_email_marketing).to be(true)
      end

      it 'creates newsletter subscriber record' do
        expect { subject }.to change { Spree::NewsletterSubscriber.where(email: user.email, user: user).count }.by(1)
      end
    end

    context 'when user unsubscribes from the newsletter' do
      let(:accepts_email_marketing) { false }

      it 'tracks the unsubscribed_from_newsletter event' do
        expect(controller).to receive(:track_event).with('unsubscribed_from_newsletter', { email: 'test@example.com', user: user })
        subject

        expect(response).to have_http_status(:ok)
        expect(user.reload.accepts_email_marketing).to be(false)
      end

      context 'with newsletter subscriber record' do
        before do
          create(:newsletter_subscriber, email: user.email, user: user)
          create(:newsletter_subscriber, email: 'foo@bar.com')
        end

        it 'removes newsletter subscriber record' do
          expect { subject }.to change { Spree::NewsletterSubscriber.where(email: user.email, user: user).count }.by(-1)
        end
      end
    end
  end
end
