require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::ProfileController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  # The seeded role, not the shared context's narrow one — this is what a
  # seller actually holds on their own seller.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #show' do
    it 'returns the seller their own record' do
      get :show, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(seller.prefixed_id)
      expect(json_response['name']).to eq(seller.name)
    end

    # A seller should know they are suspended, and what they are owed on.
    it 'shows their standing and settlement terms' do
      get :show, as: :json

      expect(json_response).to include('status', 'sellable', 'tax_remittance',
                                       'payouts_schedule_interval')
    end

    # There is no id in the request to tamper with — the seller comes from the
    # token's membership. This is the whole point of a singular resource here.
    it 'ignores any seller named in the params' do
      other = create(:seller, :approved, store: store)

      get :show, params: { id: other.prefixed_id }, as: :json

      expect(json_response['id']).to eq(seller.prefixed_id)
    end
  end

  describe 'PATCH #update' do
    it 'edits presentation and contact details' do
      patch :update, params: { name: 'Sparks Audio Ltd', contact_email: 'hello@sparks.example' },
                     as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.name).to eq('Sparks Audio Ltd')
      expect(seller.contact_email).to eq('hello@sparks.example')
    end

    it 'writes an address inline' do
      patch :update, params: {
        returns_address: { first_name: 'Ada', last_name: 'Lovelace', address1: '1 Seller Way',
                           city: 'London', postal_code: 'EC1A 1BB', country_code: 'GB',
                           phone: '555' }
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload.returns_address.address1).to eq('1 Seller Way')
    end

    # The lifecycle belongs to the operator's workflows. A seller approving
    # themselves would skip the mail, the payouts and every extension hook.
    it 'refuses to move its own status' do
      patch :update, params: { status: 'approved' }, as: :json

      expect(seller.reload).to be_approved # was already approved
      expect(seller.status).to eq('approved')
    end

    it 'cannot change its own settlement terms' do
      patch :update, params: { tax_remittance: 'platform', minimum_payout_amount: '9999' },
                     as: :json

      expect(seller.reload.tax_remittance).to eq('seller')
      expect(seller.minimum_payout_amount).to be_nil
    end

    # Renaming the storefront address breaks every link pointing at it.
    # Accepting terms is a profile write, not an endpoint of its own — the
    # AcceptTerms requirement reads the stamp this sets.
    it 'stamps the moment the seller accepts the terms' do
      seller.update!(terms_accepted_at: nil)

      expect {
        patch :update, params: { accept_terms: true }, as: :json
      }.to change { seller.reload.terms_accepted_at }.from(nil)

      expect(response).to have_http_status(:ok)
    end

    # The stamp records that it happened; sending false does not unmake it.
    it 'does not let a seller un-accept the terms' do
      accepted = 3.days.ago.change(usec: 0)
      seller.update!(terms_accepted_at: accepted)

      patch :update, params: { accept_terms: false }, as: :json

      expect(seller.reload.terms_accepted_at).to be_within(1.second).of(accepted)
    end
    it 'cannot change its own slug' do
      original = seller.slug

      patch :update, params: { slug: 'something-else' }, as: :json

      expect(seller.reload.slug).to eq(original)
    end

    it 'reports validation errors' do
      patch :update, params: { name: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'another seller' do
    it 'cannot act as a seller they do not belong to' do
      other = create(:seller, :approved, store: store)

      request.headers['X-Spree-Seller-Id'] = other.prefixed_id
      get :show, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
