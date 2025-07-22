require 'spec_helper'

RSpec.describe Spree::Account::NewsletterController, type: :controller do
  let(:store) { @default_store }
  let(:user) { create(:user, email: 'test@example.com') }

  render_views

  before do
    allow(controller).to receive(:current_store).and_return(store)
    allow(controller).to receive(:try_spree_current_user).and_return(user)
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
    end

    context 'when user unsubscribes from the newsletter' do
      let(:accepts_email_marketing) { false }

      it 'tracks the unsubscribed_from_newsletter event' do
        expect(controller).to receive(:track_event).with('unsubscribed_from_newsletter', { email: 'test@example.com', user: user })
        subject

        expect(response).to have_http_status(:ok)
        expect(user.reload.accepts_email_marketing).to be(false)
      end
    end
  end
end
