require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Companies::TaxExemptionCertificatesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) { create(:company, store: store) }
  let(:germany) { create(:country, iso: 'DE', name: 'Germany') }

  before { request.headers.merge!(headers) }

  def pdf_blob
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('%PDF-1.4 certificate'),
      filename: 'resale.pdf',
      content_type: 'application/pdf'
    )
  end

  describe 'GET #index' do
    it 'lists the company certificates with whether each counts' do
      create(:tax_exemption_certificate, :verified, company: company,
                                                    certificate_number: 'DE-1', reason_code: 'resale',
                                                    country: germany)

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('cert_')
      expect(row['certificate_number']).to eq('DE-1')
      expect(row['status']).to eq('verified')
      expect(row['country_iso']).to eq('DE')
      expect(row['active']).to be(true)
      expect(row['can_be_deleted']).to be(false)
    end

    # The status alone cannot answer this — a verified certificate stops
    # counting once its date passes.
    it 'reports a lapsed certificate as inactive' do
      create(:tax_exemption_certificate, :expired, company: company)

      get :index, params: { company_id: company.prefixed_id }, as: :json

      row = json_response['data'].first
      expect(row['status']).to eq('verified')
      expect(row['lapsed']).to be(true)
      expect(row['active']).to be(false)
    end

    it '404s under another store company' do
      get :index, params: { company_id: create(:company, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'records a certificate awaiting verification' do
      post :create, params: {
        company_id: company.prefixed_id,
        certificate_number: 'DE-RESALE-7',
        reason_code: 'resale',
        country_iso: germany.iso
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('pending')
      expect(json_response['country_iso']).to eq('DE')
      expect(company.tax_exemption_certificates.sole.country).to eq(germany)
    end

    it 'attaches a document from a direct upload' do
      post :create, params: {
        company_id: company.prefixed_id,
        certificate_number: 'DE-1', reason_code: 'resale',
        document: pdf_blob.signed_id
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['document_filename']).to eq('resale.pdf')
      expect(company.tax_exemption_certificates.sole.document).to be_attached
    end

    # Without the rescue this is a 500.
    it 'rejects a tampered signed id with a validation error' do
      post :create, params: {
        company_id: company.prefixed_id,
        certificate_number: 'DE-1', reason_code: 'resale',
        document: 'not-a-real-signed-id'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'requires a certificate number and a reason' do
      post :create, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #verify' do
    let!(:certificate) { create(:tax_exemption_certificate, company: company) }

    it 'accepts the certificate and records who did' do
      patch :verify, params: { company_id: company.prefixed_id, id: certificate.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('verified')
      expect(certificate.reload.verified_at).to be_present
    end

    it 'refuses one that is not awaiting a decision' do
      certificate.update!(status: 'revoked')

      patch :verify, params: { company_id: company.prefixed_id, id: certificate.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(certificate.reload).to be_revoked
    end

    it 'reports a handler veto as a validation failure' do
      Spree.hooks.register('tax_exemption_certificates.verify.validate') { |flow| flow.reject!('registry down') }

      patch :verify, params: { company_id: company.prefixed_id, id: certificate.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(certificate.reload).to be_pending
      Spree.hooks.clear!
    end
  end

  describe 'PATCH #revoke' do
    it 'withdraws a verified certificate' do
      certificate = create(:tax_exemption_certificate, :verified, company: company)

      patch :revoke, params: { company_id: company.prefixed_id, id: certificate.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(certificate.reload).to be_revoked
    end
  end

  describe 'DELETE #destroy' do
    it 'removes one still awaiting a decision' do
      certificate = create(:tax_exemption_certificate, company: company)

      delete :destroy, params: { company_id: company.prefixed_id, id: certificate.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
    end

    it 'refuses a verified one — revoke instead' do
      certificate = create(:tax_exemption_certificate, :verified, company: company)

      delete :destroy, params: { company_id: company.prefixed_id, id: certificate.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(certificate.reload).to be_verified
    end
  end

  describe 'GET #download' do
    it 'streams the document rather than redirecting to storage' do
      certificate = create(:tax_exemption_certificate, company: company)
      certificate.document.attach(pdf_blob.signed_id)

      get :download, params: { company_id: company.prefixed_id, id: certificate.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('certificate')
    end

    it 'reports a certificate with nothing attached' do
      certificate = create(:tax_exemption_certificate, company: company)

      get :download, params: { company_id: company.prefixed_id, id: certificate.prefixed_id }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
