require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::StoreController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  # `@default_store` is a shared in-memory object across the suite; reload it
  # so each example starts from the persisted state and isn't tripped up by
  # AR change tracking from earlier rolled-back updates.
  before { store.reload }
  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    subject { get :show, as: :json }

    it 'returns ok' do
      subject
      expect(response).to have_http_status(:ok)
    end

    it 'serializes the prefixed id, not the raw integer DB id' do
      # Regression: a previous version of the serializer listed `:id` in
      # `attributes`, which overrode `BaseSerializer#id` and exposed the
      # raw integer primary key.
      subject
      expect(json_response['id']).to eq(store.prefixed_id)
      expect(json_response['id']).to start_with('store_')
      expect(json_response['id']).not_to eq(store.id)
      expect(json_response['id']).not_to eq(store.id.to_s)
    end

    it 'returns the store name' do
      subject
      expect(json_response['name']).to eq(store.name)
    end

    context 'when the store has no allowed origins' do
      it 'serializes url from storefront_url (falling back to formatted_url)' do
        # Regression: the previous serializer exposed the raw `url` column,
        # not the customer-facing storefront URL.
        subject
        expect(json_response['url']).to eq(store.storefront_url)
        expect(json_response['url']).to eq(store.formatted_url)
      end
    end

    context 'when the store has an allowed origin' do
      before do
        store.allowed_origins.create!(origin: 'https://shop.example.com')
      end

      it 'serializes url from the first allowed origin' do
        subject
        expect(json_response['url']).to eq('https://shop.example.com')
      end
    end

    it 'includes computed default_currency, default_locale and supported lists' do
      subject
      expect(json_response).to include(
        'default_currency' => store.default_currency,
        'default_locale' => store.default_locale
      )
      expect(json_response['supported_currencies']).to be_an(Array)
      expect(json_response['supported_locales']).to be_an(Array)
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: params, as: :json }

    context 'with valid params' do
      let(:params) { { name: 'Renamed Store' } }

      it 'updates the store and returns ok' do
        subject
        expect(response).to have_http_status(:ok)
        expect(store.reload.name).to eq('Renamed Store')
      end

      it 'returns the prefixed id in the response (not the raw DB id)' do
        subject
        expect(json_response['id']).to eq(store.prefixed_id)
        expect(json_response['id']).to start_with('store_')
      end

      it 'returns the storefront_url in the url field' do
        subject
        expect(json_response['url']).to eq(store.reload.storefront_url)
      end
    end

    context 'with invalid params' do
      let(:params) { { name: '' } }

      it 'returns a validation error' do
        subject
        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end

    context 'without authentication' do
      let(:headers) { {} }
      let(:params) { { name: 'Renamed Store' } }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
