require 'spec_helper'
require 'spree/api/testing_support/v3/base'

# The seller-facing endpoint, end to end and against Stripe.
#
# It lives in this gem rather than in spree_api because that is where both
# halves meet: the controller comes from the API engine, the provider that
# answers it comes from here, and only here is there a Stripe key to record
# against. A controller spec in spree_api can only stub the provider, which
# is what let a payload Stripe rejects pass every test it had.
RSpec.describe 'Seller payout account', type: :request do
  let(:store) { @default_store }
  let!(:gateway) { create(:stripe_gateway, store: store) }
  let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:headers) do
    token = Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )

    {
      'Authorization' => "Bearer #{token}",
      'X-Spree-Seller-Id' => seller.prefixed_id,
      'CONTENT_TYPE' => 'application/json'
    }
  end
  let(:urls) do
    { refresh_url: 'https://example.test/onboarding', return_url: 'https://example.test/onboarding' }
  end

  before { store.update!(preferred_payout_provider: 'SpreeStripe::PayoutProvider') }

  describe 'POST /api/v3/seller/onboarding/payout_account' do
    it 'answers with somewhere the seller can finish setting up',
       vcr: { cassette_name: 'seller_payout_account_link' } do
      post '/api/v3/seller/onboarding/payout_account', params: urls.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['url']).to start_with('https://connect.stripe.com/')
    end

    it 'remembers the account it opened, so a second visit reuses it',
       vcr: { cassette_name: 'seller_payout_account_link_records_account' } do
      post '/api/v3/seller/onboarding/payout_account', params: urls.to_json, headers: headers

      expect(seller.reload.payout_account_reference(SpreeStripe::PayoutProvider)).to start_with('acct_')
    end

    # A marketplace settling by hand has nowhere to send anybody.
    it 'answers with no link when the store pays its sellers itself' do
      store.update!(preferred_payout_provider: '')

      post '/api/v3/seller/onboarding/payout_account', params: urls.to_json, headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['url']).to be_nil
    end

    it 'refuses a seller who is not signed in' do
      post '/api/v3/seller/onboarding/payout_account',
           params: urls.to_json,
           headers: { 'CONTENT_TYPE' => 'application/json' }

      expect(response).to have_http_status(:unauthorized)
    end

    # Somebody has to say where to come back to, and core does not know the
    # panel's routes.
    it 'refuses a request that names nowhere to return to' do
      post '/api/v3/seller/onboarding/payout_account', params: {}.to_json, headers: headers

      expect(response).to have_http_status(:bad_request)
    end
  end
end
