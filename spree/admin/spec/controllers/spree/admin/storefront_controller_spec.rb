# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Admin::StorefrontController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe 'authorization' do
    context 'without store management permission' do
      before do
        allow_any_instance_of(described_class).to receive(:current_ability).and_return(Spree::Ability.new(nil))
      end

      it 'denies access' do
        get :show

        expect(response).to redirect_to(spree.admin_forbidden_path)
      end
    end
  end

  describe 'GET #show' do
    subject(:show) { get :show, params: params }

    let(:params) { {} }

    context 'with an active publishable key' do
      let!(:api_key) { create(:api_key, store: store) }

      it 'renders and reuses the existing key' do
        expect { show }.not_to change(Spree::ApiKey, :count)

        expect(response).to render_template(:show)
        expect(assigns[:publishable_key]).to eq(api_key)
      end
    end

    context 'without a publishable key' do
      it 'creates one for the storefront' do
        expect { show }.to change { store.api_keys.active.publishable.count }.from(0).to(1)

        expect(assigns[:publishable_key].name).to eq('Storefront')
      end

      it 'does not reuse a revoked key' do
        revoked = create(:api_key, :revoked, store: store)

        show

        expect(assigns[:publishable_key]).not_to eq(revoked)
      end
    end

    context 'with Vercel callback params' do
      let(:params) do
        {
          'deployment-url' => 'my-shop.vercel.app',
          'project-dashboard-url' => 'https://vercel.com/acme/my-shop'
        }
      end

      it 'normalizes the deployment origin and renders the confirmation' do
        show

        expect(assigns[:deployment_origin]).to eq('https://my-shop.vercel.app')
        expect(assigns[:deployment_origin_allowed]).to be false
        expect(assigns[:vercel_dashboard_url]).to eq('https://vercel.com/acme/my-shop')
        expect(response.body).to include('https://my-shop.vercel.app')
      end

      context 'when the deployed origin is already allowed' do
        before { create(:allowed_origin, store: store, origin: 'https://my-shop.vercel.app') }

        it 'flags it as allowed' do
          show

          expect(assigns[:deployment_origin_allowed]).to be true
        end
      end

      context 'with invalid callback params' do
        let(:params) do
          {
            'deployment-url' => 'not a url',
            'project-dashboard-url' => 'https://evil.example.com/phishing'
          }
        end

        it 'ignores them' do
          show

          expect(assigns[:deployment_origin]).to be_nil
          expect(assigns[:vercel_dashboard_url]).to be_nil
        end
      end
    end
  end

  describe 'PATCH #update' do
    subject(:update_storefront) { patch :update, params: params }

    let(:params) { { storefront_url: 'myshop.com', add_allowed_origin: '1' } }

    it 'saves the normalized storefront url and allows the origin' do
      expect { update_storefront }.to change { store.allowed_origins.count }.by(1)

      expect(store.reload.preferred_storefront_url).to eq('https://myshop.com')
      expect(store.allowed_origins.last.origin).to eq('https://myshop.com')
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(spree.admin_storefront_path)
    end

    context 'without the add_allowed_origin flag' do
      let(:params) { { storefront_url: 'https://app.myshop.com' } }

      it 'only saves the preference' do
        expect { update_storefront }.not_to change(Spree::AllowedOrigin, :count)

        expect(store.reload.preferred_storefront_url).to eq('https://app.myshop.com')
      end
    end

    it 'overwrites an existing storefront url' do
      store.update!(preferred_storefront_url: 'https://old.example.com')

      update_storefront

      expect(store.reload.preferred_storefront_url).to eq('https://myshop.com')
    end

    context 'with an invalid url' do
      let(:params) { { storefront_url: 'not a url' } }

      it 'saves nothing and sets an error flash' do
        expect { update_storefront }.not_to change(Spree::AllowedOrigin, :count)

        expect(store.reload.preferred_storefront_url).to be_blank
        expect(flash[:error]).to be_present
      end
    end
  end

  describe 'POST #allow_origin' do
    subject(:allow_origin) { post :allow_origin, params: { origin: origin } }

    let(:origin) { 'https://my-shop.vercel.app' }

    it 'creates the allowed origin and sets the storefront url preference' do
      expect { allow_origin }.to change { store.allowed_origins.count }.by(1)

      expect(store.allowed_origins.last.origin).to eq(origin)
      expect(store.reload.preferred_storefront_url).to eq(origin)
      expect(flash[:success]).to be_present
      expect(response).to redirect_to(spree.admin_storefront_path)
    end

    it 'is idempotent for an already allowed origin' do
      create(:allowed_origin, store: store, origin: origin)

      expect { allow_origin }.not_to(change { store.allowed_origins.count })

      expect(flash[:success]).to be_present
    end

    it 'normalizes a bare host' do
      post :allow_origin, params: { origin: 'my-shop.vercel.app' }

      expect(store.allowed_origins.last.origin).to eq('https://my-shop.vercel.app')
    end

    context 'when the storefront url preference is already set' do
      before { store.update!(preferred_storefront_url: 'https://existing.example.com') }

      it 'does not overwrite it' do
        allow_origin

        expect(store.reload.preferred_storefront_url).to eq('https://existing.example.com')
      end
    end

    context 'with an invalid origin' do
      let(:origin) { 'not a url' }

      it 'creates nothing and sets an error flash' do
        expect { allow_origin }.not_to change(Spree::AllowedOrigin, :count)

        expect(flash[:error]).to be_present
        expect(store.reload.preferred_storefront_url).to be_blank
      end
    end
  end
end
