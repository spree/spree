module Spree
  module Api
    module V3
      module Admin
        # Admin-only: certificates are back-office evidence with no storefront
        # surface, so there is no store serializer to extend.
        class TaxExemptionCertificateSerializer < V3::BaseSerializer
          typelize certificate_number: :string, reason_code: :string, status: :string,
                   issuing_authority: [:string, nullable: true],
                   company_id: :string,
                   country_iso: [:string, nullable: true], state_code: [:string, nullable: true],
                   active: :boolean, lapsed: :boolean, can_be_deleted: :boolean,
                   document_filename: [:string, nullable: true],
                   document_byte_size: ['number | null'],
                   document_url: [:string, nullable: true],
                   metadata: 'Record<string, unknown> | null'

          attributes :certificate_number, :reason_code, :status, :issuing_authority, :metadata,
                     issued_at: :iso8601, expires_at: :iso8601, verified_at: :iso8601,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :company_id do |certificate|
            certificate.company&.prefixed_id
          end

          # The jurisdiction the certificate holds in, in the same vocabulary the
          # tax lines use.
          attributes :country_iso, :state_code

          # Whether it counts right now — the status alone can't say, since a
          # verified certificate stops counting once its date passes.
          attribute :active do |certificate|
            certificate.verified? && !certificate.lapsed?
          end

          attribute :lapsed do |certificate|
            certificate.lapsed?
          end

          # Lets the dashboard hide a delete the model will refuse.
          attribute :can_be_deleted do |certificate|
            certificate.can_be_deleted?
          end

          attribute :document_filename do |certificate|
            certificate.document.blob&.filename&.to_s if certificate.document.attached?
          end

          attribute :document_byte_size do |certificate|
            certificate.document.blob&.byte_size if certificate.document.attached?
          end

          # Our own endpoint rather than a pre-signed URL: the controller streams
          # the bytes, so admin auth runs on every download of a confidential
          # document.
          attribute :document_url do |certificate|
            next nil unless certificate.document.attached?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_admin_company_tax_exemption_certificate_path(
              company_id: certificate.company.prefixed_id, id: certificate.prefixed_id
            )
          end
        end
      end
    end
  end
end
