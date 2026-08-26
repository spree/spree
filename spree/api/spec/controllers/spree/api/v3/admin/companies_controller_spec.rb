require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CompaniesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) do
    create(:company, store: store, name: 'Acme Industrial').tap { |record| record.set_external_id('erp', 'ACME-1') }
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the store companies' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('comp_')
      expect(row['name']).to eq('Acme Industrial')
      expect(row['external_references']).to eq('erp' => 'ACME-1')
      expect(row['kind']).to eq('company')
      expect(row['parent_id']).to be_nil
    end

    it 'hides companies belonging to another store' do
      other = create(:company, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).not_to include(other.prefixed_id)
    end

    it 'counts children and members without a request per row' do
      create(:company, store: store, parent: company, kind: 'division')
      create(:company_membership, company: company)

      get :index, as: :json

      row = json_response['data'].find { |r| r['id'] == company.prefixed_id }
      expect(row['children_count']).to eq(1)
      expect(row['members_count']).to eq(1)
    end

    it 'filters roots and children through Ransack' do
      child = create(:company, store: store, parent: company, kind: 'division')

      get :index, params: { q: { parent_id_null: 1 } }, as: :json
      expect(json_response['data'].map { |r| r['id'] }).to contain_exactly(company.prefixed_id)

      get :index, params: { q: { parent_id_eq: company.prefixed_id } }, as: :json
      expect(json_response['data'].map { |r| r['id'] }).to contain_exactly(child.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'expands children on request' do
      child = create(:company, store: store, parent: company, kind: 'division', name: 'Berlin Division')

      get :show, params: { id: company.prefixed_id, expand: 'children' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['children'].first['name']).to eq('Berlin Division')
      expect(json_response['children'].first['id']).to eq(child.prefixed_id)
    end

    it 'expands the address book and memberships on request' do
      create(:company_address, owner: company, label: 'HQ')
      create(:company_membership, company: company)

      get :show, params: { id: company.prefixed_id, expand: 'addresses,memberships' }, as: :json

      expect(json_response['addresses'].first['label']).to eq('HQ')
      expect(json_response['memberships'].first['email']).to be_present
    end

    it '404s for another store company' do
      get :show, params: { id: create(:company, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a root company bound to the current store' do
      post :create, params: { name: 'Globex' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Globex')
      expect(json_response['kind']).to eq('company')
      expect(Spree::Company.find_by(name: 'Globex').store).to eq(store)
    end

    it 'creates a division under a parent' do
      post :create, params: { name: 'West Plant', kind: 'division', parent_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['kind']).to eq('division')
      expect(json_response['parent_id']).to eq(company.prefixed_id)
    end

    it '404s a parent belonging to another store' do
      foreign = create(:company, store: create(:store))

      post :create, params: { name: 'X', parent_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a division at the root' do
      post :create, params: { name: 'Rootless', kind: 'division' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'records the external identity the connector sent' do
      post :create, params: { name: 'Globex', external_references: [{ system: 'erp', external_id: 'GLBX' }] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['external_references']).to eq('erp' => 'GLBX')
      expect(Spree::Company.find_by(name: 'Globex').external_id_for('erp')).to eq('GLBX')
    end

    it 'updates the existing record when the external id is already known' do
      expect do
        post :create, params: { name: 'Acme Renamed', external_references: [{ system: 'erp', external_id: 'ACME-1' }] },
                      as: :json
      end.not_to change(Spree::Company, :count)

      expect(company.reload.name).to eq('Acme Renamed')
    end

    it 'rejects a company with no name' do
      post :create, params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'renames a company' do
      patch :update, params: { id: company.prefixed_id, name: 'Acme Global' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(company.reload.name).to eq('Acme Global')
    end

    it 'addresses the company by the identity the external system knows' do
      patch :update, params: { id: 'external:erp:ACME-1', name: 'Acme Via ERP' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(company.reload.name).to eq('Acme Via ERP')
    end

    it 'leaves other systems alone when one connector writes its key' do
      company.set_external_id('crm', 'CUST-9')

      patch :update, params: { id: company.prefixed_id,
                               external_references: [{ system: 'erp', external_id: 'ACME-2' }] }, as: :json

      expect(company.reload.external_id_for('erp')).to eq('ACME-2')
      expect(company.external_id_for('crm')).to eq('CUST-9')
    end

    it 'does not reach a company in another store through its external id' do
      other = create(:company, store: create(:store))
      other.set_external_id('erp', 'OTHER-1')

      patch :update, params: { id: 'external:erp:OTHER-1', name: 'Hijacked' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(other.reload.name).not_to eq('Hijacked')
    end

    it 're-parents a node, revalidating the tree' do
      other_root = create(:company, store: store)
      child = create(:company, store: store, parent: company, kind: 'division')

      patch :update, params: { id: child.prefixed_id, parent_id: other_root.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(child.reload.parent).to eq(other_root)
    end

    it 'refuses a cycle' do
      child = create(:company, store: store, parent: company)

      patch :update, params: { id: company.prefixed_id, parent_id: child.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the node and its subtree' do
      create(:company, store: store, parent: company, kind: 'division')

      delete :destroy, params: { id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Company.count).to eq(0)
    end
  end
end
