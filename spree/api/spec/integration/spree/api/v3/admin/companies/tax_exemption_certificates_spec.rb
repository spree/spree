# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Tax Exemption Certificates API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let!(:company) { create(:company, store: store) }
  let(:germany) { create(:country, iso: 'DE', name: 'Germany') }
  let!(:certificate) do
    create(:tax_exemption_certificate, company: company,
                                       certificate_number: 'DE-RESALE-1', reason_code: 'resale')
  end

  def pdf_blob
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('%PDF-1.4 certificate'),
      filename: 'resale.pdf',
      content_type: 'application/pdf'
    )
  end

  path '/api/v3/admin/companies/{company_id}/tax_exemption_certificates' do
    let(:company_id) { company.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :company_id, in: :path, type: :string, required: true

    get 'List tax exemption certificates' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns a business's exemption evidence. `active` is the field that decides whether a certificate
        exempts a sale: a verified certificate stops counting once its expiry date passes, so the status
        alone does not answer it.
      DESC
      admin_scope :read, :customers

      admin_sdk_example 'tax-exemption-certificates/list'

      response '200', 'certificates found' do
        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].pluck('certificate_number')).to include('DE-RESALE-1')
        end
      end
    end

    post 'Create a tax exemption certificate' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Records exemption evidence against a business. Certificates start `pending` and exempt nothing
        until verified.

        `country_iso` and `state_code` say where the certificate holds — omit both for one valid
        everywhere, give only the country for one valid throughout it. `document` takes an ActiveStorage
        signed blob id obtained from `POST /api/v3/admin/direct_uploads`.
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'tax-exemption-certificates/create'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          certificate_number: { type: :string, example: 'DE-RESALE-7' },
          reason_code: { type: :string, description: 'Becomes the tax provider\'s entity use code.', example: 'resale' },
          country_iso: { type: :string, nullable: true, example: 'DE' },
          state_code: { type: :string, nullable: true, example: 'BE' },
          expires_at: { type: :string, format: 'date-time', nullable: true },
          issuing_authority: { type: :string, nullable: true, example: 'Finanzamt Berlin' },
          document: {
            type: :string,
            description: 'ActiveStorage signed blob id from POST /api/v3/admin/direct_uploads.',
            example: 'eyJfcmFpbHMiOnsiZGF0YSI6MX0=--signed'
          }
        },
        required: %w[certificate_number reason_code]
      }

      response '201', 'certificate created' do
        let(:body) do
          {
            certificate_number: 'DE-RESALE-7',
            reason_code: 'resale',
            country_iso: germany.iso,
            document: pdf_blob.signed_id
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('pending')
          expect(data['document_filename']).to eq('resale.pdf')
        end
      end

      response '422', 'invalid request' do
        let(:body) { { reason_code: 'resale' } }

        run_test!
      end
    end
  end

  path '/api/v3/admin/companies/{company_id}/tax_exemption_certificates/{id}/verify' do
    let(:company_id) { company.prefixed_id }
    let(:id) { certificate.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :company_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Verify a tax exemption certificate' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Accepts the certificate as evidence, which is what makes it exempt sales. Only a pending
        certificate can be accepted — re-accepting a revoked one would restore evidence that was
        deliberately withdrawn. An installation that checks numbers against a registry, or requires a
        second approval, can refuse here, and the refusal is returned as a validation error.
      DESC
      admin_scope :write, :customers

      admin_sdk_example 'tax-exemption-certificates/verify'

      response '200', 'certificate verified' do
        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('verified')
        end
      end
    end
  end

  path '/api/v3/admin/companies/{company_id}/tax_exemption_certificates/{id}/revoke' do
    let(:company_id) { company.prefixed_id }
    let(:id) { create(:tax_exemption_certificate, :verified, company: company).prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :company_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    patch 'Revoke a tax exemption certificate' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Withdraws accepted evidence. A verified certificate cannot be deleted — how a sale was taxed has to remain explainable — so revoking is the way out.'
      admin_scope :write, :customers

      admin_sdk_example 'tax-exemption-certificates/revoke'

      response '200', 'certificate revoked' do
        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('revoked')
        end
      end
    end
  end

  path '/api/v3/admin/companies/{company_id}/tax_exemption_certificates/{id}/download' do
    let(:company_id) { company.prefixed_id }
    let(:'x-spree-api-key') { secret_api_key.plaintext_token }

    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true
    parameter name: :company_id, in: :path, type: :string, required: true
    parameter name: :id, in: :path, type: :string, required: true

    get 'Download a certificate document' do
      tags 'Companies'
      produces 'application/octet-stream'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Streams the uploaded document. Deliberately not a storage link: the bytes come through the API so
        the same credentials apply to every read of a confidential document. Requires only read access.
      DESC
      admin_scope :read, :customers

      response '200', 'document streamed' do
        let(:id) do
          create(:tax_exemption_certificate, company: company).tap do |record|
            record.document.attach(pdf_blob.signed_id)
          end.prefixed_id
        end

        run_test!
      end

      response '422', 'no document attached' do
        let(:id) { certificate.prefixed_id }

        run_test!
      end
    end
  end
end
