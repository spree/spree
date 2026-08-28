require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::SellersController, 'onboarding', type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:seller) { create(:seller, :onboarding, store: store) }

  before do
    request.headers.merge!(headers)
    Spree::SellerRequirement.where(store_id: store.id).destroy_all
  end

  describe 'GET #onboarding' do
    # The operator approves or sends back a seller on the strength of what
    # they published — a line reading "Done" with no way to read the document
    # is not something anyone can approve on.
    it 'embeds the policy a seller published, so the operator can read it' do
      create(:policy_requirement, store: store, name: 'Returns Policy')
      seller.policies.create!(name: 'Returns Policy', body: '<p>Send it back within 30 days.</p>')

      get :onboarding, params: { id: seller.prefixed_id }, as: :json

      row = json_response['requirements'].find { |r| r['kind'] == 'policy' }
      expect(row['status']).to eq('complete')
      expect(row['required_policy_name']).to eq('Returns Policy')
      expect(row['published_policy']['body_html']).to include('within 30 days')
    end

    it 'names the document without embedding one while it is still owed' do
      create(:policy_requirement, store: store, name: 'Shipping Policy')

      get :onboarding, params: { id: seller.prefixed_id }, as: :json

      row = json_response['requirements'].find { |r| r['kind'] == 'policy' }
      expect(row['status']).to eq('incomplete')
      expect(row['required_policy_name']).to eq('Shipping Policy')
      expect(row).not_to have_key('published_policy')
    end

    it "does not reach another seller's policy of the same name" do
      create(:policy_requirement, store: store, name: 'Returns Policy')
      other = create(:seller, store: store)
      other.policies.create!(name: 'Returns Policy', body: '<p>Not theirs.</p>')

      get :onboarding, params: { id: seller.prefixed_id }, as: :json

      row = json_response['requirements'].find { |r| r['kind'] == 'policy' }
      expect(row['status']).to eq('incomplete')
      expect(row).not_to have_key('published_policy')
    end

    it 'shows where the seller stands, in the operator’s order' do
      create(:accept_terms_requirement, store: store)
      create(:billing_address_requirement, store: store, required: false)

      get :onboarding, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('onboarding')
      expect(json_response['progress']).to eq('done' => 0, 'total' => 2)

      rows = json_response['requirements']
      expect(rows.map { |r| r['kind'] }).to eq(%w[accept_terms billing_address])
      expect(rows.first['status']).to eq('incomplete')
      expect(rows.first['required']).to be true
      expect(rows.second['required']).to be false
    end

    it 'reflects what the seller has done' do
      create(:accept_terms_requirement, store: store)
      seller.update!(terms_accepted_at: Time.current)

      get :onboarding, params: { id: seller.prefixed_id }, as: :json

      expect(json_response['requirements'].first['status']).to eq('complete')
      expect(json_response['progress']).to eq('done' => 1, 'total' => 1)
    end

    it 'carries the submission a reviewer has to look at' do
      requirement = create(:operator_review_requirement, store: store)
      create(:seller_requirement_submission, seller: seller, requirement: requirement, note: 'ready')

      get :onboarding, params: { id: seller.prefixed_id }, as: :json

      row = json_response['requirements'].first
      expect(row['status']).to eq('pending')
      expect(row['submission']['note']).to eq('ready')
    end
  end

  describe 'PATCH #approve' do
    it 'refuses while the checklist is unfinished' do
      create(:accept_terms_requirement, store: store)

      patch :approve, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(seller.reload).not_to be_approved
    end

    it 'admits the seller when the operator overrides deliberately' do
      create(:accept_terms_requirement, store: store)

      patch :approve, params: { id: seller.prefixed_id, override_requirements: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload).to be_approved
    end

    it 'admits without an override once the checklist is done' do
      create(:accept_terms_requirement, store: store)
      seller.update!(terms_accepted_at: Time.current)

      patch :approve, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload).to be_approved
    end
  end

  describe 'PATCH #reopen_onboarding' do
    it 'sends a seller awaiting review back with a note' do
      seller.update!(status: 'ready_for_review')

      patch :reopen_onboarding, params: { id: seller.prefixed_id, note: 'Returns address is a PO box' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(seller.reload).to be_onboarding
      expect(seller.metadata['onboarding_reopened_note']).to eq('Returns address is a PO box')
    end

    it 'refuses a seller who is not awaiting review' do
      patch :reopen_onboarding, params: { id: seller.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
