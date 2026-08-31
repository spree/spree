require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::TaxIdentifiersController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let(:vat_number) { eu_vat_number(0) }
  let(:corrected_vat_number) { eu_vat_number(1) }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists only this seller's registrations" do
      seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number)
      other_seller = create(:seller, :approved, store: store)
      other_seller.tax_identifiers.create!(kind: 'eu_vat', value: corrected_vat_number)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('value')).to contain_exactly(vat_number)
    end
  end

  describe 'POST #create' do
    it 'records a registration' do
      post :create, params: { kind: 'eu_vat', value: vat_number }, as: :json

      expect(response).to have_http_status(:created)
      expect(seller.reload.tax_identifiers.find_by(kind: 'eu_vat').value).to eq(vat_number)
    end

    # A business trading in two regimes holds a registration in each, exactly
    # as a company does — they are not alternatives.
    it 'holds one registration per regime' do
      post :create, params: { kind: 'eu_vat', value: vat_number }, as: :json
      post :create, params: { kind: 'gb_vat', value: 'GB123456789' }, as: :json

      expect(response).to have_http_status(:created)
      expect(seller.reload.tax_identifiers.pluck(:kind)).to contain_exactly('eu_vat', 'gb_vat')
    end

    it 'refuses a second registration of the same kind' do
      seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number)

      post :create, params: { kind: 'eu_vat', value: corrected_vat_number }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    # Silently dropping it would answer 2xx to a number that was never stored.
    it 'refuses a malformed number' do
      post :create, params: { kind: 'eu_vat', value: 'DE123' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(seller.reload.tax_identifiers).to be_empty
    end
  end

  describe 'PATCH #update' do
    it 'corrects the number' do
      identifier = seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number)

      patch :update, params: { id: identifier.prefixed_id, value: corrected_vat_number }, as: :json

      expect(response).to have_http_status(:ok)
      expect(identifier.reload.value).to eq(corrected_vat_number)
    end

    it "refuses another seller's registration" do
      other_seller = create(:seller, :approved, store: store)
      theirs = other_seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number)

      patch :update, params: { id: theirs.prefixed_id, value: corrected_vat_number }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the registration' do
      identifier = seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number)

      delete :destroy, params: { id: identifier.prefixed_id }, as: :json

      expect(seller.reload.tax_identifiers).to be_empty
    end
  end

  describe 'POST #validate' do
    # Core format-checks eu_vat but asks no registry, so there is nothing to
    # queue and the seller is told why rather than left waiting.
    it 'reports that no registry validator is installed' do
      identifier = seller.tax_identifiers.create!(kind: 'eu_vat', value: vat_number)

      post :validate, params: { id: identifier.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('tax_id_not_validatable')
    end
  end
end
