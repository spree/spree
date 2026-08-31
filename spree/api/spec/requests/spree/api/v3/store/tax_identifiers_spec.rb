require 'spec_helper'

RSpec.describe 'Store tax identifiers', type: :request do
  include_context 'API v3 Store authenticated'

  describe 'the customer own registration' do
    let(:vat_number) { eu_vat_number(0) }
    let(:corrected_vat_number) { eu_vat_number(1) }

    it 'is upserted, read back and removed' do
      # Typed as a human would: grouped with spaces and in lower case.
      typed = vat_number.downcase.scan(/.{1,3}/).join(' ')

      put '/api/v3/store/customers/me/tax_identifier',
          params: { kind: 'eu_vat', value: " #{typed} " }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['value']).to eq(vat_number)
      # The verdict is the platform's bookkeeping, not the buyer's business.
      expect(body).not_to have_key('validation_status')

      put '/api/v3/store/customers/me/tax_identifier',
          params: { kind: 'eu_vat', value: corrected_vat_number }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(user.tax_identifiers.count).to eq(1)

      get '/api/v3/store/customers/me/tax_identifier',
          params: { kind: 'eu_vat' }, headers: headers, as: :json
      expect(JSON.parse(response.body)['value']).to eq(corrected_vat_number)

      delete '/api/v3/store/customers/me/tax_identifier',
             params: { kind: 'eu_vat' }, headers: headers, as: :json
      expect(response).to have_http_status(:no_content)

      get '/api/v3/store/customers/me/tax_identifier',
          params: { kind: 'eu_vat' }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end

    # A buyer can hold several registrations, so the singular endpoints have to
    # be told which one. Guessing meant a DELETE removed whichever row came back
    # first — not the buyer's choice, and not predictable.
    it 'refuses to guess which registration was meant' do
      create(:tax_identifier, owner: user, kind: 'eu_vat')
      create(:tax_identifier, owner: user, kind: 'gb_vat', value: 'GB123456789')

      delete '/api/v3/store/customers/me/tax_identifier', headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']['code']).to eq('parameter_missing')
      expect(user.tax_identifiers.count).to eq(2)
    end
  end

  describe 'a checkout override on the cart' do
    let(:cart) { create(:cart_with_line_items, line_items_count: 1, store: store, customer: user) }
    let(:profile_vat_number) { eu_vat_number(2) }
    let(:override_vat_number) { eu_vat_number(3) }
    let(:entered_vat_number) { eu_vat_number(4) }

    it 'reads the customer registration when the cart has no override' do
      create(:tax_identifier, owner: user, kind: 'eu_vat', value: profile_vat_number)

      get "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          headers: headers.merge('x-spree-token' => cart.token), as: :json

      # What the provider will be handed, which is the question a checkout asks.
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['value']).to eq(profile_vat_number)
    end

    it 'prefers the cart override over the customer registration' do
      create(:tax_identifier, owner: user, kind: 'eu_vat', value: profile_vat_number)
      create(:tax_identifier, owner: cart, kind: 'eu_vat', value: override_vat_number)

      get "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(JSON.parse(response.body)['value']).to eq(override_vat_number)
    end

    it 'clears only the override, leaving the customer registration alone' do
      profile = create(:tax_identifier, owner: user, kind: 'eu_vat', value: profile_vat_number)
      create(:tax_identifier, owner: cart, kind: 'eu_vat', value: override_vat_number)

      delete "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
             headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(response).to have_http_status(:no_content)
      expect(profile.reload).to be_present
      expect(cart.reload.tax_identifier).to be_nil
    end

    it 'has nothing of its own to delete when the registration is inherited' do
      create(:tax_identifier, owner: user, kind: 'eu_vat')

      delete "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
             headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(response).to have_http_status(:not_found)
    end

    # The claim this endpoint stores drives tax and is frozen onto the order at
    # completion, so it must never be half-replaced: sending a new kind alone
    # used to relabel the number already there under a regime it was not issued
    # for.
    it 'refuses to relabel the existing number under a new kind' do
      create(:tax_identifier, owner: cart, kind: 'eu_vat', value: override_vat_number)

      put "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          params: { kind: 'gb_vat' },
          headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['error']['code']).to eq('parameter_missing')

      override = cart.reload.tax_identifier
      expect(override.kind).to eq('eu_vat')
      expect(override.value).to eq(override_vat_number)
    end

    it 'is stored against the cart and read back' do
      put "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
          params: { kind: 'eu_vat', value: entered_vat_number },
          headers: headers.merge('x-spree-token' => cart.token), as: :json

      expect(response).to have_http_status(:created)
      expect(cart.reload.tax_identifier.value).to eq(entered_vat_number)

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
        create(:tax_rate, store: store, country_code: cart.tax_country&.iso,
                          tax_category: line_item.tax_category, amount: 0.1, included_in_price: false)
      end

      it 'happens when a registration is entered' do
        expect(cart.tax_lines).to be_empty

        put "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
            params: { kind: 'eu_vat', value: entered_vat_number },
            headers: headers.merge('x-spree-token' => cart.token), as: :json

        expect(response).to have_http_status(:created)
        expect(cart.reload.tax_lines.sole.amount).to eq(1.0)
        expect(cart.additional_tax_total).to eq(1.0)
        expect(cart.total).to eq(11.0)
      end

      it 'happens when the override is cleared' do
        create(:tax_identifier, owner: cart, kind: 'eu_vat', value: override_vat_number)

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

      with_tax_identifier_validator('eu_vat', 'SpecStoreValidator') do
        put "/api/v3/store/carts/#{cart.prefixed_id}/tax_identifier",
            params: { kind: 'eu_vat', value: '123' },
            headers: headers.merge('x-spree-token' => cart.token), as: :json
      end

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'the snapshot on a placed order' do
    let(:order) { create(:completed_order_with_totals, store: store, customer: user) }
    let(:snapshot_vat_number) { eu_vat_number(5) }

    it 'is readable and cannot be written' do
      create(:tax_identifier, :on_order, owner: order, value: snapshot_vat_number)

      get "/api/v3/store/orders/#{order.prefixed_id}/tax_identifier", headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['value']).to eq(snapshot_vat_number)

      put "/api/v3/store/orders/#{order.prefixed_id}/tax_identifier",
          params: { kind: 'eu_vat', value: eu_vat_number(6) },
          headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
      expect(order.reload.tax_identifier.value).to eq(snapshot_vat_number)
    end
  end
end
