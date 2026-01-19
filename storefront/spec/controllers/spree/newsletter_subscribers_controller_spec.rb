require 'spec_helper'

RSpec.describe Spree::NewsletterSubscribersController, type: :controller, newsletter: true do
  render_views

  let(:store) { @default_store }

  before do
    allow(controller).to receive(:current_store).and_return(store)
  end

  describe 'POST #create' do
    subject(:request) { post :create, params: newsletter_params, format: request_format }

    let(:request_format) { :html }
    let(:newsletter_params) { { newsletter: { email: newsletter_email } } }
    let(:newsletter_email) { 'test@example.com' }

    let(:user) { create(:user, email: newsletter_email, accepts_email_marketing: false) }

    context 'with new subscription' do
      it 'creates a new newsletter subscription record' do
        expect { request }.to change(Spree::NewsletterSubscriber, :count).by(1)
      end

      it 'sets success flash message' do
        request

        expect(flash[:success]).to eq Spree.t('storefront.newsletter_subscribers.success')
      end

      it 'redirects to root path for html format' do
        request

        expect(response).to redirect_to spree.root_path
      end

      context 'with turbo stream format' do
        let(:request_format) { :turbo_stream }

        it 'renders turbo stream template for turbo_stream format' do
          request

          expect(response).to have_http_status(:success)
          expect(response.media_type).to eq Mime[:turbo_stream]
        end
      end
    end

    context 'with existing subscription' do
      before do
        create(:newsletter_subscriber, :verified, email: newsletter_email)
      end

      it 'sets notice flash message' do
        request

        expect(flash[:notice]).to eq Spree.t('storefront.newsletter_subscribers.already_subscribed')
      end

      it 'does not create a new newsletter subscription record' do
        expect { request }.not_to change(Spree::NewsletterSubscriber, :count)
      end

      it 'redirects to root path for html format' do
        request

        expect(response).to redirect_to spree.root_path
      end

      context 'with turbo stream format' do
        let(:request_format) { :turbo_stream }

        it 'renders turbo stream template for turbo_stream format' do
          request

          expect(response).to have_http_status(:success)
          expect(response.media_type).to eq Mime[:turbo_stream]
        end
      end
    end

    context 'with signed in user' do
      context 'with the same email' do
        before do
          allow(controller).to receive(:try_spree_current_user).and_return(user)
        end

        it 'updates accepts_email_marketing for existing user' do
          expect { request }.to change { user.reload.accepts_email_marketing }.to(true)
        end
      end

      context 'with the different email' do
        let(:another_user) { create(:user, email: 'another_user@example.com', accepts_email_marketing: false) }

        before do
          allow(controller).to receive(:try_spree_current_user).and_return(another_user)
          user
        end

        it 'does not update accepts_email_marketing for user with the same email' do
          expect { request }.not_to change { user.reload.accepts_email_marketing }
        end

        it 'does not update accepts_email_marketing for the current user' do
          expect { request }.not_to change { another_user.reload.accepts_email_marketing }
        end
      end
    end

    context 'with newsletter section' do
      let!(:newsletter_section) { create(:newsletter_page_section) }

      it 'loads newsletter section when section_id provided' do
        post :create, params: newsletter_params.merge(section_id: newsletter_section.id)
        expect(assigns(:newsletter_section)).to eq newsletter_section
      end
    end

    context 'with invalid params' do
      let(:newsletter_email) { 'invalid_email' }

      it 'sets error flash message' do
        subject

        expect(flash[:error]).to be_present
      end
    end
  end

  describe 'GET #verify' do
    subject(:request) { get :verify, params: { token: token } }

    let(:token) { '1234567890' }

    context 'with valid token' do
      before do
        create(:newsletter_subscriber, :unverified, verification_token: token)
      end

      it 'verifies the newsletter subscriber' do
        expect { request }.to change { Spree::NewsletterSubscriber.verified.count }.by(1)
      end
    end

    context 'with already verified subscriber' do
      before do
        create(:newsletter_subscriber, :verified, verification_token: token)
      end

      it 'sets error flash message' do
        subject

        expect(flash[:alert]).to be_present
      end

      it 'redirects to root path for html format' do
        request

        expect(response).to redirect_to spree.root_path
      end
    end

    context 'with invalid token' do
      let(:token) { 'invalid-token' }

      it 'sets error flash message' do
        subject

        expect(flash[:alert]).to be_present
      end

      it 'redirects to root path for html format' do
        request

        expect(response).to redirect_to spree.root_path
      end
    end

    context 'with blank token' do
      let(:token) { '' }

      it 'sets error flash message' do
        subject

        expect(flash[:alert]).to be_present
      end

      it 'redirects to root path for html format' do
        request

        expect(response).to redirect_to spree.root_path
      end
    end
  end
end
