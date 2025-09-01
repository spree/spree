require 'spec_helper'

RSpec.describe Spree::NewsletterSubscribersController, type: :controller do
  render_views

  let(:store) { @default_store }

  before do
    allow(controller).to receive(:current_store).and_return(create(:store))
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

    context 'with existing user (when signed in as that user)' do
      before do
        allow(controller).to receive(:try_spree_current_user).and_return(user)
      end

      it 'updates accepts_email_marketing for existing user' do
        expect { request }.to change { user.reload.accepts_email_marketing }.to(true)
      end
    end

    context 'with existing user (when signed as another user)' do
      before do
        allow(controller).to receive(:try_spree_current_user).and_return(user)
      end

      it 'updates accepts_email_marketing for existing user' do
        expect { request }.to change { user.reload.accepts_email_marketing }.to(true)
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
end
