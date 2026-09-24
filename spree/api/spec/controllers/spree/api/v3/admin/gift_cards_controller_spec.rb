require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::GiftCardsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:gift_card) { create(:gift_card, store: store, amount: 50, currency: 'USD') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns gift cards in the current store' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |g| g['id'] }).to include(gift_card.prefixed_id)
    end

    it 'excludes gift cards from other stores' do
      other_store = create(:store)
      other_card = create(:gift_card, store: other_store, amount: 25, currency: 'USD')

      subject
      ids = json_response['data'].map { |g| g['id'] }
      expect(ids).to include(gift_card.prefixed_id)
      expect(ids).not_to include(other_card.prefixed_id)
    end

    it 'surfaces display_amount as a formatted money string and ISO timestamps' do
      subject
      entry = json_response['data'].find { |g| g['id'] == gift_card.prefixed_id }
      expect(entry['display_amount']).to match(/\$50\.00/)
      expect(entry['currency']).to eq('USD')
      expect(entry['created_at']).to match(/\A\d{4}-\d{2}-\d{2}T/)
    end

    it 'does not embed customer or created_by by default' do
      gift_card.update!(customer: create(:user, email: 'vip@example.com'))

      subject
      entry = json_response['data'].find { |g| g['id'] == gift_card.prefixed_id }
      expect(entry).not_to have_key('customer')
      expect(entry).not_to have_key('created_by')
      expect(entry).not_to have_key('gift_card_batch')
    end

    it 'exposes flat prefixed-ID references even without expand' do
      customer = create(:user)
      admin = create(:admin_user)
      gift_card.update!(customer: customer, created_by: admin)

      subject
      entry = json_response['data'].find { |g| g['id'] == gift_card.prefixed_id }
      expect(entry['customer_id']).to eq(customer.prefixed_id)
      expect(entry['created_by_id']).to eq(admin.prefixed_id)
    end

    it 'embeds customer + created_by when expand=customer,created_by is passed' do
      customer = create(:user, email: 'vip@example.com')
      admin = create(:admin_user, email: 'staff@example.com')
      gift_card.update!(customer: customer, created_by: admin)

      get :index, params: { expand: 'customer,created_by' }, as: :json
      entry = json_response['data'].find { |g| g['id'] == gift_card.prefixed_id }
      expect(entry['customer']['id']).to eq(customer.prefixed_id)
      expect(entry['customer']['email']).to eq('vip@example.com')
      expect(entry['created_by']['email']).to eq('staff@example.com')
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: gift_card.prefixed_id }, as: :json }

    it 'returns the gift card' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(gift_card.prefixed_id)
      expect(json_response['code']).to eq(gift_card.display_code)
      expect(json_response['status']).to eq('active')
    end

    it 'returns 404 for a gift card from another store' do
      other_card = create(:gift_card, store: create(:store))

      get :show, params: { id: other_card.prefixed_id }, as: :json
      expect(response).to have_http_status(:not_found)
    end

    it 'reports expired status when the card is past its expiration' do
      expired = create(:gift_card, :expired, store: store, amount: 5, currency: 'USD')
      get :show, params: { id: expired.prefixed_id }, as: :json
      expect(json_response['status']).to eq('expired')
      expect(json_response['expired']).to be(true)
      expect(json_response['active']).to be(false)
    end
  end

  describe 'POST #create' do
    let(:create_params) { { amount: '25.00', currency: 'USD', expires_at: '2030-12-31' } }

    it 'creates a gift card scoped to the current store and stamps created_by' do
      expect { post :create, params: create_params, as: :json }.to change(Spree::GiftCard, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['display_amount']).to match(/\$25\.00/)
      expect(json_response['currency']).to eq('USD')
      created = Spree::GiftCard.last
      expect(created.store).to eq(store)
      # `created_by` is auto-stamped by Spree::Api::V3::ResourceController#build_resource.
      expect(created.created_by_id).to eq(admin_user.id)
    end

    # `created_by` on a gift card still points at admin users only — it
    # converts to a polymorphic actor in 6.1 — so a key-authenticated create
    # records nobody rather than raising on the type mismatch.
    context 'when a secret API key made the call' do
      let(:headers) { api_key_headers }

      it 'creates the gift card without an actor' do
        expect { post :create, params: create_params, as: :json }.to change(Spree::GiftCard, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(Spree::GiftCard.last.created_by_id).to be_nil
      end
    end

    it 'attaches a customer when customer_id is passed as a prefixed ID' do
      customer = create(:user, email: 'buyer@example.com')

      post :create, params: create_params.merge(customer_id: customer.prefixed_id, expand: 'customer'), as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['customer']['id']).to eq(customer.prefixed_id)
      expect(json_response['customer']['email']).to eq('buyer@example.com')
    end

    # The id is resolved through the caller's ability, never looked up raw
    # across every customer.
    it 'refuses a raw integer customer id' do
      customer = create(:user)

      post :create, params: create_params.merge(customer_id: customer.id), as: :json

      expect(response).to have_http_status(:not_found)
    end

    # Attaching a customer embeds their record in the response, so a key
    # cleared only for gift cards must not be able to read customers this way.
    context 'with a key that holds gift cards but not customers' do
      let(:gift_card_key) { create(:api_key, :secret, store: store, scopes: ['write_gift_cards']) }
      let(:headers) { { 'x-spree-api-key' => gift_card_key.plaintext_token } }

      it 'refuses to attach a customer' do
        customer = create(:user, email: 'secret@example.com')

        expect {
          post :create, params: create_params.merge(customer_id: customer.prefixed_id, expand: 'customer'), as: :json
        }.not_to change(Spree::GiftCard, :count)

        expect(response).to have_http_status(:forbidden)
        expect(response.body).not_to include('secret@example.com')
      end

      it 'does not embed the customer through expand' do
        gift_card.update!(customer: create(:user, email: 'secret@example.com'))

        get :show, params: { id: gift_card.prefixed_id, expand: 'customer' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response).not_to have_key('customer')
      end
    end

    it 'returns 422 when amount is missing' do
      post :create, params: { currency: 'USD' }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('validation_error')
      expect(json_response['error']['details']).to have_key('amount')
    end

    it 'returns 422 when amount is not positive' do
      post :create, params: { amount: '0', currency: 'USD' }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'auto-generates a code when not provided' do
      post :create, params: create_params, as: :json
      expect(response).to have_http_status(:created)
      expect(json_response['code']).to match(/\A[A-Z0-9]+\z/)
    end

    it 'honors a caller-supplied code' do
      post :create, params: create_params.merge(code: 'WELCOME50'), as: :json
      expect(response).to have_http_status(:created)
      expect(json_response['code']).to eq('WELCOME50')
    end
  end

  describe 'PATCH #update' do
    it 'updates editable attributes on an active card' do
      patch :update, params: { id: gift_card.prefixed_id, amount: '75.00' }, as: :json
      expect(response).to have_http_status(:ok)
      expect(json_response['display_amount']).to match(/\$75\.00/)
    end

    it 'returns 404 for a card from another store' do
      other_card = create(:gift_card, store: create(:store))
      patch :update, params: { id: other_card.prefixed_id, amount: '5.00' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes an unused gift card' do
      expect { delete :destroy, params: { id: gift_card.prefixed_id }, as: :json }
        .to change(Spree::GiftCard, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'refuses to delete a redeemed gift card' do
      redeemed = create(:gift_card, :redeemed, store: store, amount: 10, currency: 'USD')
      delete :destroy, params: { id: redeemed.prefixed_id }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::GiftCard.exists?(redeemed.id)).to be(true)
    end
  end
end
