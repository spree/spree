require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::RequirementSubmissionsController, type: :controller do
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

  describe 'POST #create' do
    # An attestation is accepted outright: nobody reviews "I confirm".
    it 'accepts an attestation the seller ticks' do
      requirement = create(:attestation_requirement, store: store)

      post :create, params: { requirement_id: requirement.prefixed_id, note: 'I confirm' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response).to include('status' => 'accepted', 'note' => 'I confirm')
    end

    # Something an operator checks lands pending, and stays that way until
    # they act on it.
    it 'leaves an operator-reviewed submission pending' do
      requirement = create(:operator_review_requirement, store: store)

      post :create, params: { requirement_id: requirement.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('pending')
    end

    it 'refuses a document submission with no file' do
      requirement = create(:document_requirement, store: store)

      post :create, params: { requirement_id: requirement.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(seller.requirement_submissions).to be_empty
    end

    # A requirement id from another marketplace is not a 403 telling the
    # seller it exists — it simply is not on their checklist.
    it "404s on another store's requirement" do
      other_store = create(:store)
      theirs = create(:attestation_requirement, store: other_store)

      post :create, params: { requirement_id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #download' do
    let(:requirement) { create(:document_requirement, store: store) }

    # Real PDF magic bytes, not just a .pdf name: the model decides a file's
    # type by reading it, so a plain string declared as a PDF is refused.
    PDF_BYTES = "%PDF-1.4\npassport"

    def submission_for(target_seller)
      create(:seller_requirement_submission, seller: target_seller, requirement: requirement).tap do |submission|
        submission.file.attach(
          io: StringIO.new(PDF_BYTES), filename: 'id.pdf', content_type: 'application/pdf'
        )
        submission.save!
      end
    end

    it 'serves the seller their own document' do
      submission = submission_for(seller)

      get :download, params: { id: submission.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq(PDF_BYTES)
    end

    # Identity documents: one seller reading another's is the thing this
    # endpoint exists to make impossible.
    it "404s on another seller's document" do
      other = create(:seller, :onboarding, store: store)
      theirs = submission_for(other)

      get :download, params: { id: theirs.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
