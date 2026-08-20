require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::SellerRequirementSubmissionsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, :onboarding, store: store) }
  let(:requirement) { create(:operator_review_requirement, store: store, name: 'VAT number check') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists what this seller submitted' do
      submission = create(:seller_requirement_submission, seller: seller, requirement: requirement, note: 'PL123')

      get :index, params: { seller_id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to eq(submission.prefixed_id)
      expect(row['status']).to eq('pending')
      expect(row['note']).to eq('PL123')
      expect(row['requirement_name']).to eq('VAT number check')
    end

    it 'never shows another seller’s submissions' do
      other = create(:seller, store: store)
      create(:seller_requirement_submission, seller: other, requirement: requirement)

      get :index, params: { seller_id: seller.prefixed_id }, as: :json

      expect(json_response['data']).to be_empty
    end

    it '404s on a seller belonging to another marketplace' do
      elsewhere = create(:seller, store: create(:store))

      get :index, params: { seller_id: elsewhere.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #accept' do
    it 'settles the requirement' do
      submission = create(:seller_requirement_submission, seller: seller, requirement: requirement)

      patch :accept, params: { seller_id: seller.prefixed_id, id: submission.prefixed_id,
                               review_note: 'Checked against the register' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('accepted')
      expect(submission.reload.review_note).to eq('Checked against the register')
      expect(requirement.satisfied?(seller)).to be true
    end
  end

  describe 'PATCH #reject' do
    it 'sends it back with a reason' do
      submission = create(:seller_requirement_submission, seller: seller, requirement: requirement)

      patch :reject, params: { seller_id: seller.prefixed_id, id: submission.prefixed_id,
                               review_note: 'That number does not resolve' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('rejected')
      expect(requirement.status_for(seller)).to eq('rejected')
    end
  end

  describe 'POST #create' do
    it 'waives a requirement for one seller' do
      post :create, params: { seller_id: seller.prefixed_id, requirement_id: requirement.prefixed_id,
                              review_note: 'Verified offline' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('waived')
      expect(requirement.satisfied?(seller)).to be true
    end

    it '404s on a requirement from another marketplace' do
      elsewhere = create(:document_requirement, store: create(:store))

      post :create, params: { seller_id: seller.prefixed_id, requirement_id: elsewhere.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET #download' do
    it 'serves the file the seller uploaded' do
      document = create(:document_requirement, store: store)
      submission = create(:seller_requirement_submission, :with_file, seller: seller, requirement: document)

      get :download, params: { seller_id: seller.prefixed_id, id: submission.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Disposition']).to include('thinking-cat.jpg')
    end

    it 'refuses when there is nothing attached' do
      submission = create(:seller_requirement_submission, seller: seller, requirement: requirement)

      get :download, params: { seller_id: seller.prefixed_id, id: submission.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
