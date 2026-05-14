require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PaymentMethodsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:payment_method) { create(:check_payment_method, stores: [store]) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns store-scoped payment methods' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |pm| pm['id'] }).to include(payment_method.prefixed_id)
    end

    context 'when payment method belongs to a different store' do
      let!(:other_store) { create(:store) }
      let!(:other_payment_method) { create(:check_payment_method, stores: [other_store]) }

      it 'is not returned' do
        get :index, as: :json

        expect(json_response['data'].map { |pm| pm['id'] }).not_to include(other_payment_method.prefixed_id)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the payment method' do
      get :show, params: { id: payment_method.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment_method.prefixed_id)
    end

    context 'when the payment method has a :password preference' do
      let!(:payment_method) do
        bogus = create(:bogus_payment_method, stores: [store])
        bogus.set_preference(:dummy_secret_key, 'sk_live_super_secret_value')
        bogus.set_preference(:dummy_key, 'pk_live_visible_key')
        bogus.save!
        bogus
      end

      it 'masks the password preference and never leaks the plaintext secret' do
        get :show, params: { id: payment_method.prefixed_id }, as: :json

        secret = json_response.dig('preferences', 'dummy_secret_key')
        expect(secret).to start_with(Spree::Preferences::Masking::TOKEN)
        expect(secret).to eq("#{Spree::Preferences::Masking::TOKEN}alue")
        expect(response.body).not_to include('sk_live_super_secret_value')
      end

      it 'returns non-password preferences in plaintext' do
        get :show, params: { id: payment_method.prefixed_id }, as: :json

        expect(json_response.dig('preferences', 'dummy_key')).to eq('pk_live_visible_key')
      end

      it 'masks the password preference in the index response too' do
        get :index, as: :json

        entry = json_response['data'].find { |pm| pm['id'] == payment_method.prefixed_id }
        expect(entry.dig('preferences', 'dummy_secret_key')).to start_with(Spree::Preferences::Masking::TOKEN)
        expect(response.body).not_to include('sk_live_super_secret_value')
      end
    end
  end

  describe 'POST #create' do
    let(:create_params) do
      {
        type: 'check',
        name: 'Check on delivery',
        description: 'Pay by physical check',
        active: true,
        display_on: 'back_end'
      }
    end

    it 'creates a payment method of the given STI subclass' do
      expect { post :create, params: create_params, as: :json }.
        to change(Spree::PaymentMethod, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['type']).to eq('check')
      expect(json_response['name']).to eq('Check on delivery')

      created = Spree::PaymentMethod.find_by_prefix_id(json_response['id'])
      expect(created.stores).to include(store)
    end

    it 'rejects an unknown subclass' do
      post :create, params: create_params.merge(type: 'NotARealClass'), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('unknown_payment_method_type')
    end
  end

  describe 'PATCH #update' do
    it 'updates the payment method' do
      patch :update, params: { id: payment_method.prefixed_id, name: 'Updated', active: false }, as: :json

      expect(response).to have_http_status(:ok)
      expect(payment_method.reload.name).to eq('Updated')
      expect(payment_method.reload.active).to be false
    end

    context 'when the payment method has a :password preference' do
      let!(:payment_method) do
        bogus = create(:bogus_payment_method, stores: [store])
        bogus.set_preference(:dummy_secret_key, 'sk_live_existing_secret')
        bogus.save!
        bogus
      end

      it 'preserves the existing secret when the submitted value is a masked round-trip' do
        patch :update,
              params: {
                id: payment_method.prefixed_id,
                preferences: { dummy_secret_key: "#{Spree::Preferences::Masking::TOKEN}cret" }
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(payment_method.reload.preferred_dummy_secret_key).to eq('sk_live_existing_secret')
      end

      it 'replaces the secret when the submitted value is a new plaintext' do
        patch :update,
              params: {
                id: payment_method.prefixed_id,
                preferences: { dummy_secret_key: 'sk_live_brand_new_secret' }
              },
              as: :json

        expect(response).to have_http_status(:ok)
        expect(payment_method.reload.preferred_dummy_secret_key).to eq('sk_live_brand_new_secret')
      end

      it 'still updates non-password preferences alongside a masked password round-trip' do
        patch :update,
              params: {
                id: payment_method.prefixed_id,
                preferences: {
                  dummy_secret_key: "#{Spree::Preferences::Masking::TOKEN}cret",
                  dummy_key: 'pk_live_new_public_key'
                }
              },
              as: :json

        expect(response).to have_http_status(:ok)
        payment_method.reload
        expect(payment_method.preferred_dummy_secret_key).to eq('sk_live_existing_secret')
        expect(payment_method.preferred_dummy_key).to eq('pk_live_new_public_key')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'soft-deletes the payment method' do
      expect { delete :destroy, params: { id: payment_method.prefixed_id }, as: :json }.
        to change { Spree::PaymentMethod.where(id: payment_method.id).count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'GET #types' do
    it 'returns the available payment provider subclasses' do
      get :types, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      types = json_response['data'].map { |entry| entry['type'] }
      expect(types).to include('bogus', 'store_credit', 'custom_payment_source_method')
    end

    it 'filters out providers already installed in the current store' do
      get :types, as: :json

      types = json_response['data'].map { |entry| entry['type'] }
      # The seeded `check_payment_method` is scoped to `store`, so `check`
      # must not be offered again — that's how the admin avoids
      # double-installing a provider.
      expect(types).not_to include('check')
    end

    # Bogus declares `preference :dummy_secret_key, :password, default: 'SECRETKEY123'`.
    # The discovery endpoint must not leak the default — that's a secret
    # the gateway author shipped, just like a saved value would be.
    it 'redacts password defaults in each provider\'s preference_schema' do
      get :types, as: :json

      bogus = json_response['data'].find { |entry| entry['type'] == 'bogus' }
      secret_field = bogus['preference_schema'].find { |f| f['key'] == 'dummy_secret_key' }
      expect(secret_field['default']).to be_nil
      expect(response.body).not_to include('SECRETKEY123')
    end

    context 'with provider gems that ship a top-level Gateway class' do
      # Reproduces the duplicate-key bug from the admin SPA: two providers
      # whose demodulized leaf is `"Gateway"` must still get unique `type`
      # values so the React `<SelectItem key>` is unique and the registry
      # lookup resolves to the right subclass.
      before do
        stub_const('SpreeStripe', Module.new)
        stub_const('SpreeStripe::Gateway', Class.new(Spree::Gateway))
        stub_const('SpreeAdyen', Module.new)
        stub_const('SpreeAdyen::Gateway', Class.new(Spree::Gateway))

        allow(Spree::PaymentMethod).to receive(:providers).and_return(
          [SpreeStripe::Gateway, SpreeAdyen::Gateway, Spree::PaymentMethod::Check]
        )
      end

      it 'exposes a unique `type` for every provider' do
        get :types, as: :json

        types = json_response['data'].map { |entry| entry['type'] }
        expect(types).to contain_exactly('stripe', 'adyen')
        expect(types).to eq(types.uniq)
      end
    end
  end
end
