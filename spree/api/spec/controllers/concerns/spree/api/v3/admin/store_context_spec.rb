require 'spec_helper'

# Covers Admin::StoreContext using TaxCategoriesController as a representative
# Admin::ResourceController. Deliberately does NOT use the 'API v3 Admin'
# shared context — that stubs +current_store+, which is the mechanic under
# test here.
RSpec.describe Spree::Api::V3::Admin::TaxCategoriesController, type: :controller do
  render_views

  let(:store) { @default_store }
  let(:other_store) { create(:store) }

  let(:admin_user) { create(:admin_user) } # membership on the default store
  let(:admin_jwt) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      admin_user,
      audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN
    )
  end

  describe 'JWT sessions' do
    before { request.headers['Authorization'] = "Bearer #{admin_jwt}" }

    context 'with X-Spree-Store-Id naming a store the admin has a role on' do
      before do
        create(:role_user, user: admin_user, role: Spree::Role.default_admin_role(other_store))
        request.headers['X-Spree-Store-Id'] = other_store.prefixed_id
      end

      it 'resolves the requested store' do
        get :index, as: :json

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_store)).to eq(other_store)
      end
    end

    context 'with X-Spree-Store-Id naming a store the admin has NO role on' do
      before { request.headers['X-Spree-Store-Id'] = other_store.prefixed_id }

      it 'returns 403' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with an unknown X-Spree-Store-Id' do
      before { request.headers['X-Spree-Store-Id'] = 'store_doesnotexist' }

      it 'returns 404' do
        get :index, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without the header' do
      # No Spree::Deprecation here by design: /me and the auth endpoints
      # structurally cannot send the header, and deprecations-as-errors would
      # turn every login bootstrap into a 500. A once-per-process log line
      # covers the multi-store-client nudge instead.
      it 'falls back to the default store without raising deprecations' do
        expect(Spree::Deprecation).not_to receive(:warn)

        get :index, as: :json

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_store)).to eq(store)
      end
    end
  end

  describe 'secret API keys' do
    let(:foreign_key) { create(:api_key, :secret, store: other_store) }

    before { request.headers['X-Spree-Api-Key'] = foreign_key.plaintext_token }

    context 'without a header' do
      it "resolves the key's bound store" do
        get :index, as: :json

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_store)).to eq(other_store)
      end
    end

    context 'with a matching X-Spree-Store-Id' do
      before { request.headers['X-Spree-Store-Id'] = other_store.prefixed_id }

      it 'authenticates normally' do
        get :index, as: :json

        expect(response).to have_http_status(:ok)
        expect(controller.send(:current_store)).to eq(other_store)
      end
    end

    context 'with a conflicting X-Spree-Store-Id' do
      before { request.headers['X-Spree-Store-Id'] = store.prefixed_id }

      it 'returns 403' do
        get :index, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
