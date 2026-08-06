require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Customers::TaxIdentifiersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:customer) { create(:user) }
  let!(:tax_identifier) { create(:tax_identifier, :verified, customer: customer, kind: 'eu_vat', value: 'DE123456789') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the customer registrations with their verdict' do
      get :index, params: { customer_id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['kind']).to eq('eu_vat')
      expect(row['value']).to eq('DE123456789')
      expect(row['validation_status']).to eq('verified')
      expect(row['validation_evidence']['registry']).to eq('vies')
      expect(row['customer_id']).to eq(customer.prefixed_id)
    end

    it 'reports whether this installation can check the kind at all' do
      get :index, params: { customer_id: customer.prefixed_id }, as: :json

      expect(json_response['data'].first['validatable']).to be(false)
    end
  end

  describe 'POST #create' do
    it 'adds a registration to the customer' do
      expect do
        post :create, params: { customer_id: customer.prefixed_id, kind: 'gb_vat', value: 'GB123456789' }, as: :json
      end.to change { customer.tax_identifiers.count }.by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to start_with('txi_')
      expect(json_response['value']).to eq('GB123456789')
    end

    it 'normalizes what was typed' do
      post :create, params: { customer_id: customer.prefixed_id, kind: 'gb_vat', value: ' gb 123 456 789 ' }, as: :json

      expect(json_response['value']).to eq('GB123456789')
    end
  end

  describe 'PATCH #update' do
    it 'updates the number' do
      patch :update, params: { customer_id: customer.prefixed_id, id: tax_identifier.prefixed_id, value: 'DE987654321' },
                     as: :json

      expect(response).to have_http_status(:ok)
      expect(tax_identifier.reload.value).to eq('DE987654321')
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the registration' do
      delete :destroy, params: { customer_id: customer.prefixed_id, id: tax_identifier.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::TaxIdentifier.find_by(id: tax_identifier.id)).to be_nil
    end
  end

  describe 'POST #validate' do
    context 'when a validator is registered for the kind' do
      around do |example|
        Spree.tax_id_validators['eu_vat'] = 'Spree::TaxIdValidator::Base'
        example.run
      ensure
        Spree.tax_id_validators.delete('eu_vat')
      end

      it 'queues a fresh registry check' do
        expect do
          post :validate, params: { customer_id: customer.prefixed_id, id: tax_identifier.prefixed_id }, as: :json
        end.to have_enqueued_job(Spree::TaxIdentifiers::ValidateJob)

        expect(response).to have_http_status(:accepted)
        expect(json_response['validation_status']).to eq('pending')
      end
    end

    context 'when nothing here can check the kind' do
      it 'says so rather than queueing a job with nothing to do' do
        post :validate, params: { customer_id: customer.prefixed_id, id: tax_identifier.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('tax_id_not_validatable')
      end
    end
  end
end
