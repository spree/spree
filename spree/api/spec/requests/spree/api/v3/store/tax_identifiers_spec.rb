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

    it 'reads the customer registration when the cart has no override' do
      create(:tax_identifier, customer: user, kind: 'eu_vat', value: 'DE123456789')

      get "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          headers: headers.merge('x-spree-token' => cart.token), as: :json

      # What the provider will be handed, which is the question a checkout asks.
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['value']).to eq('DE123456789')
    end

    it 'prefers the cart override over the customer registration' do
      create(:tax_identifier, customer: user, kind: 'eu_vat', value: 'DE123456789')
      create(:tax_identifier, customer: nil, cart: cart, kind: 'eu_vat', value: 'DE999999999')

      get "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(JSON.parse(response.body)['value']).to eq('DE999999999')
    end

    it 'clears only the override, leaving the customer registration alone' do
      profile = create(:tax_identifier, customer: user, kind: 'eu_vat', value: 'DE123456789')
      create(:tax_identifier, customer: nil, cart: cart, kind: 'eu_vat', value: 'DE999999999')

      delete "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
             headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(response).to have_http_status(:no_content)
      expect(profile.reload).to be_present
      expect(cart.reload.tax_identifier).to be_nil
    end

    it 'has nothing of its own to delete when the registration is inherited' do
      create(:tax_identifier, customer: user, kind: 'eu_vat', value: 'DE123456789')

      delete "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
             headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(response).to have_http_status(:not_found)
    end

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

    # Tax depends on the buyer's registration, so writing one has to re-cost the
    # cart and not merely store it. The rate below is configured after the cart
    # was last costed, which leaves its tax stale on purpose: tax appearing on
    # the cart is what proves the request re-estimated.
    describe 'the re-costing it triggers' do
      let(:line_item) { cart.line_items.first }
      let!(:tax_rate) do
        create(:tax_rate, store: store, country: cart.tax_country,
                          tax_category: line_item.tax_category, amount: 0.1, included_in_price: false)
      end

      it 'happens when a registration is entered' do
        expect(cart.tax_lines).to be_empty

        put "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
            params: { kind: 'eu_vat', value: 'DE555555555' },
            headers: headers.merge('x-spree-token' => cart.token), as: :json

        expect(response).to have_http_status(:created)
        expect(cart.reload.tax_lines.sole.amount).to eq(1.0)
        expect(cart.additional_tax_total).to eq(1.0)
        expect(cart.total).to eq(11.0)
      end

      it 'happens when the override is cleared' do
        create(:tax_identifier, customer: nil, cart: cart, kind: 'eu_vat', value: 'DE999999999')

        delete "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
               headers: headers.merge('x-spree-token' => cart.token), as: :json

        expect(response).to have_http_status(:no_content)
        expect(cart.reload.tax_lines.sole.amount).to eq(1.0)
        expect(cart.additional_tax_total).to eq(1.0)
      end
    end

    it 'rejects a malformed number when this installation can check the kind' do
      stub_const('SpecStoreValidator', Class.new(Spree::TaxIdentifiers::Validator::Base) do
        def self.valid_format?(value)
          value.start_with?('DE')
        end
      end)
      Spree.tax_identifier_validators['eu_vat'] = 'SpecStoreValidator'

      put "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          params: { kind: 'eu_vat', value: '123' },
          headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    ensure
      Spree.tax_identifier_validators.delete('eu_vat')
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
