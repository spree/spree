require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Companies::MembershipsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) { create(:company, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the members with who they are' do
      membership = create(:company_membership, company: company)

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to eq(membership.prefixed_id)
      expect(row['email']).to eq(membership.customer.email)
      expect(row['company_id']).to eq(company.prefixed_id)
    end

    it '404s under another store company' do
      get :index, params: { company_id: create(:company, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    context 'when the email belongs to an existing customer' do
      let!(:customer) { create(:customer, email: 'buyer@example.com') }

      it 'creates the membership immediately' do
        post :create, params: { company_id: company.prefixed_id, customer_email: 'buyer@example.com' }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['id']).to start_with('cmem_')
        expect(json_response['email']).to eq('buyer@example.com')
        expect(company.memberships.sole.customer).to eq(customer)
      end

      it 'rejects a duplicate membership' do
        create(:company_membership, company: company, customer: customer)

        post :create, params: { company_id: company.prefixed_id, customer_email: 'buyer@example.com' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when the email is unknown' do
      it 'creates an invitation instead' do
        post :create, params: { company_id: company.prefixed_id, customer_email: 'new@example.com' }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['id']).to start_with('cinv_')
        expect(json_response['email']).to eq('new@example.com')
        expect(json_response['status']).to eq('pending')
        expect(json_response).not_to have_key('token')
        expect(company.invitations.sole.inviter).to be_nil
      end
    end
  end
end
