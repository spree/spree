require 'spec_helper'

RSpec.describe Spree::NewsletterSubscribersController, type: :controller do
  render_views

  let(:store) { @default_store }

  before do
    allow(controller).to receive(:current_store).and_return(create(:store))
  end

  describe 'POST #create' do
    let(:newsletter_params) { { newsletter: { email: 'test@example.com' } } }
    let(:user) { create(:user) }

    context 'with valid params' do
      it 'creates a new newsletter subscription' do
        expect {
          post :create, params: newsletter_params
        }.to change { Spree.user_class.where(accepts_email_marketing: true).count }.by(1)
      end

      it 'sets success flash message' do
        post :create, params: newsletter_params
        expect(flash[:success]).to eq Spree.t('storefront.newsletter_subscribers.success')
      end

      it 'redirects to root path for html format' do
        post :create, params: newsletter_params
        expect(response).to redirect_to spree.root_path
      end

      it 'renders turbo stream template for turbo_stream format' do
        post :create, params: newsletter_params, format: :turbo_stream
        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq Mime[:turbo_stream]
      end
    end

    context 'with existing user (when signed in as that user)' do
      before do
        allow(controller).to receive(:try_spree_current_user).and_return(user)
        user.update(email: 'test@example.com', accepts_email_marketing: false)
      end

      it 'updates accepts_email_marketing for existing user' do
        post :create, params: newsletter_params
        expect(user.reload.accepts_email_marketing).to be true
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
      let(:invalid_params) { { newsletter: { email: 'invalid_email' } } }

      before do
        allow_any_instance_of(Spree.user_class).to receive(:save).and_return(false)
      end

      it 'sets error flash message' do
        post :create, params: invalid_params
        expect(flash[:error]).to be_present
      end
    end
  end
end
