require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::SellerRequirementsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before do
    request.headers.merge!(headers)
    store.seller_requirements.destroy_all
  end

  describe 'GET #types' do
    it 'tells the operator what a document kind accepts rather than asking' do
      get :types, params: { format: :json }

      document = json_response['data'].find { |t| t['type'] == 'document' }
      expect(document['accepted_content_types']).to include('application/pdf', 'image/jpeg')
      # Nothing to configure — the list is fixed, so it is not a preference.
      expect(document['preference_schema']).to be_empty
    end

    it 'names the records a kind takes, so the picker is a picker' do
      get :types, params: { format: :json }

      custom_fields = json_response['data'].find { |t| t['type'] == 'required_custom_fields' }
      expect(custom_fields['association_fields']).to eq(['custom_field_definition_ids'])
    end

    it 'lists the kinds an operator can add, with their configuration shape' do
      get :types, params: { format: :json }

      expect(response).to have_http_status(:ok)
      types = json_response['data']
      expect(types.map { |t| t['type'] }).to include('accept_terms', 'document', 'operator_review')

      accept_terms = types.find { |t| t['type'] == 'accept_terms' }
      expect(accept_terms['name']).to eq('Accept terms')
      expect(accept_terms['allow_multiple']).to be false
      expect(accept_terms['preference_schema']).to be_an(Array)

      document = types.find { |t| t['type'] == 'document' }
      expect(document['allow_multiple']).to be true
      expect(document['reviewed_by_operator']).to be true
    end

    it 'says which single-instance kinds the store already has' do
      create(:accept_terms_requirement, store: store)

      get :types, params: { format: :json }

      accept_terms = json_response['data'].find { |t| t['type'] == 'accept_terms' }
      expect(accept_terms['configured']).to be true
    end

    it 'says what may still be added, so the picker does not restate the rule' do
      create(:accept_terms_requirement, store: store)
      create(:document_requirement, store: store, name: 'Business registration')

      get :types, params: { format: :json }

      types = json_response['data']
      # Answers one question, already asked — not addable again.
      expect(types.find { |t| t['type'] == 'accept_terms' }['addable']).to be false
      # Carries the operator's own wording, so a second one is meaningful.
      expect(types.find { |t| t['type'] == 'document' }['addable']).to be true
      expect(types.find { |t| t['type'] == 'billing_address' }['addable']).to be true
    end
  end

  describe 'GET #index' do
    it 'lists this store’s checklist in the operator’s order' do
      first = create(:accept_terms_requirement, store: store)
      second = create(:billing_address_requirement, store: store)

      get :index, params: { format: :json }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |r| r['kind'] }).to eq(%w[accept_terms billing_address])
      expect(json_response['data'].first['id']).to eq(first.prefixed_id)
      expect(second.reload.position).to be > first.reload.position
    end

    it 'never shows another marketplace’s checklist' do
      create(:accept_terms_requirement, store: create(:store))

      get :index, params: { format: :json }

      expect(json_response['data']).to be_empty
    end
  end

  describe 'POST #create' do
    it 'adds a requirement of the chosen kind' do
      post :create, params: { type: 'billing_address', format: :json }

      expect(response).to have_http_status(:created)
      expect(json_response['kind']).to eq('billing_address')
      expect(store.seller_requirements.reload.first).to be_a(Spree::SellerRequirements::BillingAddress)
    end

    it 'takes the operator’s own wording' do
      post :create, params: {
        type: 'document', name: 'Business registration',
        description: 'A copy of your certificate of incorporation',
        format: :json
      }

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Business registration')
      expect(json_response['description']).to eq('A copy of your certificate of incorporation')
    end

    it 'attaches the custom fields the operator picked' do
      definition = create(:custom_field_definition, resource_type: 'Spree::Seller')

      post :create, params: {
        type: 'required_custom_fields',
        custom_field_definition_ids: [definition.prefixed_id],
        format: :json
      }

      expect(response).to have_http_status(:created)
      expect(json_response['custom_field_definition_ids']).to eq([definition.prefixed_id])
      expect(store.seller_requirements.reload.first.custom_field_definitions).to eq([definition])
    end

    it 'refuses a kind nobody registered' do
      post :create, params: { type: 'imaginary_check', format: :json }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a second row of a kind that answers one question' do
      create(:accept_terms_requirement, store: store)

      post :create, params: { type: 'accept_terms', format: :json }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    let(:requirement) { create(:minimum_products_requirement, store: store) }

    it 'changes what the requirement asks for' do
      patch :update, params: { id: requirement.prefixed_id, preferences: { minimum_count: 5 }, format: :json }

      expect(response).to have_http_status(:ok)
      expect(requirement.reload.preferred_minimum_count).to eq(5)
    end

    it 'switches a requirement off without deleting it' do
      patch :update, params: { id: requirement.prefixed_id, active: false, format: :json }

      expect(requirement.reload.active).to be false
    end

    it 'makes a requirement optional' do
      patch :update, params: { id: requirement.prefixed_id, required: false, format: :json }

      expect(requirement.reload.required).to be false
    end

    it 'reorders the checklist' do
      first = create(:accept_terms_requirement, store: store)
      second = create(:billing_address_requirement, store: store)

      patch :update, params: { id: second.prefixed_id, position: 1, format: :json }

      expect(store.seller_requirements.reload.map(&:class)).to eq(
        [Spree::SellerRequirements::BillingAddress, Spree::SellerRequirements::AcceptTerms]
      )
      expect(first.reload.position).to be > second.reload.position
    end

    it 'never changes a saved row’s kind' do
      patch :update, params: { id: requirement.prefixed_id, type: 'accept_terms', format: :json }

      expect(requirement.reload).to be_a(Spree::SellerRequirements::MinimumProducts)
    end

    it '404s on another marketplace’s requirement' do
      other = create(:accept_terms_requirement, store: create(:store))

      patch :update, params: { id: other.prefixed_id, active: false, format: :json }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it 'drops a requirement the marketplace no longer asks for' do
      requirement = create(:accept_terms_requirement, store: store)

      delete :destroy, params: { id: requirement.prefixed_id, format: :json }

      expect(store.seller_requirements.reload).to be_empty
    end
  end
end
