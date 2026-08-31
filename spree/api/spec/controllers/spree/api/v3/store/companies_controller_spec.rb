require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CompaniesController, type: :controller do
  render_views

  include_context 'API v3 Store authenticated'

  let(:company) { create(:company, store: store, name: 'Acme Industrial') }
  let(:division) { create(:company, store: store, kind: 'division', parent: company, name: 'Berlin') }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    it 'returns a node the member has standing over, with its ancestor path' do
      create(:company_membership, company: company, customer: user)

      get :show, params: { id: division.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Berlin')
      expect(json_response['kind']).to eq('division')
      expect(json_response['ancestors'].map { |a| a['name'] }).to eq(['Acme Industrial'])
    end

    it '404s a node the member has no standing over' do
      get :show, params: { id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '404s an ancestor of the membership node' do
      create(:company_membership, company: division, customer: user)

      get :show, params: { id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it '401s a guest' do
      request.headers['Authorization'] = nil

      get :show, params: { id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'PATCH #update' do
    it 'lets any member rename the node' do
      create(:company_membership, company: company, customer: user)

      patch :update, params: { id: company.prefixed_id, name: 'Acme Global' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(company.reload.name).to eq('Acme Global')
    end

    it 'never lets a member re-parent or retype the node' do
      create(:company_membership, company: company, customer: user)
      other_root = create(:company, store: store)

      patch :update, params: { id: division.prefixed_id, parent_id: other_root.prefixed_id, kind: 'company' }, as: :json

      expect(division.reload.parent).to eq(company)
      expect(division.kind).to eq('division')
    end
  end

  describe 'POST #create' do
    it 'founds a root company with the caller as its first member' do
      post :create, params: { name: 'Nowak Tools' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Nowak Tools')

      founded = store.companies.find_by(name: 'Nowak Tools')
      expect(founded.kind).to eq('company')
      expect(founded.parent_id).to be_nil
      expect(founded.memberships.map(&:customer)).to eq([user])
    end

    it 'stores the free-form registration answers under metadata' do
      post :create, params: { name: 'Nowak Tools', registration: { vat_number: 'PL123', employees: '50' } }, as: :json

      expect(response).to have_http_status(:created)
      expect(store.companies.last.metadata['registration']).to eq(
        'vat_number' => 'PL123', 'employees' => '50'
      )
    end

    it 'refuses a second founding by the same customer' do
      create(:company_membership, company: company, customer: user)

      post :create, params: { name: 'Second Business' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('already registered')
      expect(store.companies.where(name: 'Second Business')).to be_empty
    end

    it 'refuses an invalid registration' do
      post :create, params: { name: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it '401s a guest' do
      request.headers['Authorization'] = nil

      post :create, params: { name: 'Nowak Tools' }, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
