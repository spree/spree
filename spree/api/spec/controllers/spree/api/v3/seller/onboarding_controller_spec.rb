require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::OnboardingController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller) { create(:seller, :onboarding, store: store) }
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  before do
    store.seller_requirements.destroy_all
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #show' do
    it 'reads as finished when the marketplace asks for nothing' do
      get :show, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['progress']).to include('done' => 0, 'total' => 0)
      expect(json_response['requirements']).to eq([])
    end

    it 'returns the checklist with the seller current standing' do
      create(:accept_terms_requirement, store: store)
      create(:billing_address_requirement, store: store)
      seller.update!(terms_accepted_at: Time.current)

      get :show, as: :json

      expect(json_response['status']).to eq('onboarding')
      expect(json_response['progress']).to include('done' => 1, 'total' => 2)

      terms, billing = json_response['requirements'].sort_by { |r| r['position'] }
      expect(terms).to include('kind' => 'accept_terms', 'status' => 'complete', 'blocking' => false)
      expect(billing).to include('kind' => 'billing_address', 'status' => 'incomplete', 'blocking' => true)
    end

    # The id is what the panel posts a submission against, so losing it to a
    # value-object/serializer mismatch would be silent and fatal.
    it 'carries the requirement id each line acts on' do
      requirement = create(:document_requirement, store: store)

      get :show, as: :json

      expect(json_response['requirements'].first['id']).to eq(requirement.prefixed_id)
    end

    # Naming a seller they do not belong to resolves no `current_seller` at
    # all, so the request is refused before any checklist is read — there is
    # no path here that reads another seller's requirements.
    it "shows another seller's checklist to nobody" do
      other = create(:seller, :onboarding, store: store)
      request.headers['X-Spree-Seller-Id'] = other.prefixed_id

      get :show, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST #submit_for_review' do
    it 'moves the seller to ready_for_review once the checklist is met' do
      create(:accept_terms_requirement, store: store)
      seller.update!(terms_accepted_at: Time.current)

      post :submit_for_review, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload).to be_ready_for_review
      expect(json_response['status']).to eq('ready_for_review')
    end

    # A bare "not ready" leaves the seller guessing which of eight things it
    # meant, so the refusal names what is outstanding.
    it 'refuses while something required is outstanding, naming it' do
      create(:billing_address_requirement, store: store)

      post :submit_for_review, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to match(/billing address/i)
      expect(seller.reload).to be_onboarding
    end
  end

  describe 'POST #payout_account' do
    let(:urls) { { refresh_url: 'https://panel/onboarding', return_url: 'https://panel/onboarding?done=1' } }

    # An operator settling by hand collects bank details themselves, so there
    # is nowhere to send the seller.
    it 'answers with nothing when the provider hosts no onboarding' do
      post :payout_account, params: urls, as: :json

      expect(response).to have_http_status(:no_content)
    end

    context 'with a provider that hosts its own onboarding' do
      before do
        allow_any_instance_of(Spree::PayoutProvider::System).to receive(:onboarding_url).
          and_return('https://provider.example/setup/abc')
      end

      it 'answers with a fresh link' do
        post :payout_account, params: urls, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['url']).to eq('https://provider.example/setup/abc')
      end

      # The panel says where to come back to — core does not know its routes.
      it 'sends the panel’s own return addresses to the provider' do
        expect_any_instance_of(Spree::PayoutProvider::System).to receive(:onboarding_url).
          with(anything, hash_including(refresh_url: urls[:refresh_url], return_url: urls[:return_url])).
          and_return('https://provider.example/setup/abc')

        post :payout_account, params: urls, as: :json
      end

      it 'reports a provider that refuses rather than raising' do
        allow_any_instance_of(Spree::PayoutProvider::System).to receive(:onboarding_url).
          and_raise(Spree::Core::GatewayError, 'not configured')

        post :payout_account, params: urls, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
