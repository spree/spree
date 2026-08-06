require 'spec_helper'

RSpec.describe 'Store tax identifiers', type: :request do
  include_context 'API v3 Store authenticated'

  describe 'the customer own registration' do
    it 'is upserted, read back and removed' do
      put '/api/v3/store/customers/me/tax_identifier',
          params: { kind: 'eu_vat', value: ' de 123 456 789 ' }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['value']).to eq('DE123456789')
      # The verdict is the platform's bookkeeping, not the buyer's business.
      expect(body).not_to have_key('validation_status')

      put '/api/v3/store/customers/me/tax_identifier',
          params: { kind: 'eu_vat', value: 'DE987654321' }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(user.tax_identifiers.count).to eq(1)

      get '/api/v3/store/customers/me/tax_identifier', headers: headers, as: :json
      expect(JSON.parse(response.body)['value']).to eq('DE987654321')

      delete '/api/v3/store/customers/me/tax_identifier', headers: headers, as: :json
      expect(response).to have_http_status(:no_content)

      get '/api/v3/store/customers/me/tax_identifier', headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'a checkout override on the cart' do
    let(:cart) { create(:cart_with_line_items, line_items_count: 1, store: store, customer: user) }

    it 'is stored against the cart and read back' do
      put "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          params: { kind: 'eu_vat', value: 'DE555555555' },
          headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(response).to have_http_status(:created)
      expect(cart.reload.tax_identifier.value).to eq('DE555555555')

      get "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          headers: headers.merge('x-spree-token' => cart.token), as: :json
      expect(JSON.parse(response.body)['kind']).to eq('eu_vat')
    end

    it 'rejects a malformed number when this installation can check the kind' do
      stub_const('SpecStoreValidator', Class.new(Spree::TaxIdValidator::Base) do
        def self.valid_format?(value)
          value.start_with?('DE')
        end
      end)
      Spree.tax_id_validators['eu_vat'] = 'SpecStoreValidator'

      put "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          params: { kind: 'eu_vat', value: '123' },
          headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    ensure
      Spree.tax_id_validators.delete('eu_vat')
    end
  end

  describe 'the snapshot on a placed order' do
    let(:order) { create(:completed_order_with_totals, store: store, customer: user) }

    it 'is readable and cannot be written' do
      create(:tax_identifier, :on_order, order: order, value: 'DE111111111')

      get "/api/v3/store/orders/#{order.prefixed_id}/tax_identifier", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['value']).to eq('DE111111111')

      put "/api/v3/store/orders/#{order.prefixed_id}/tax_identifier",
          params: { kind: 'eu_vat', value: 'DE222222222' }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
      expect(order.tax_identifier.reload.value).to eq('DE111111111')
    end
  end
end
