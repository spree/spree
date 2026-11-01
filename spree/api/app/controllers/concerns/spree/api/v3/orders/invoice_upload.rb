module Spree
  module Api
    module V3
      module Orders
        # Listing and uploading invoices under the order or seller payout they
        # belong to (docs/plans/6.1-invoices-and-receipts.md). Shared by the
        # operator's and the seller's branches; `@parent` arrives already
        # fetched through the caller's own scope, so including this cannot
        # widen what a caller reaches. Reading, downloading and deleting one
        # invoice live on the top-level invoices controllers.
        module InvoiceUpload
          extend ActiveSupport::Concern

          included do
            request_params :invoice do |body|
              body.attribute :kind, :string, required: true, choices: Spree::Invoice::KINDS,
                description: 'A credit note corrects an earlier invoice or receipt and carries negative totals.'
              body.attribute :number, :string, required: true, example: 'FV/2026/11/042',
                description: "The number the issuing system gave it. Unique per issuer and kind; never Spree's order number."
              body.attribute :issued_on, :date, required: true
              body.attribute :supplied_on, :date, nullable: true, description: 'When the goods or service were supplied, if not the issue date.'
              body.attribute :currency, :currency, description: "Defaults to the order's or payout's currency."
              body.attribute :total, :decimal, required: true, description: 'Gross total. Zero or more, or zero or less for a credit note.'
              body.attribute :net_total, :decimal, nullable: true
              body.attribute :tax_total, :decimal, nullable: true
              body.attribute :original_invoice_id, :id, nullable: true,
                description: 'The invoice a credit note corrects, on the same order or payout.'
              body.attribute :external_reference, :string, nullable: true, description: "The issuing system's own id."
              body.attribute :file_signed_id, :string, required: true,
                description: "A PDF's `signed_id` from `files.upload()` with `visibility: 'private'`."
              body.attribute :metadata, :hash
            end
          end

          protected

          def model_class
            Spree::Invoice
          end

          def parent_association
            :invoices
          end

          def collection_includes
            [:issuer, { file_attachment: :blob }]
          end

          def create_workflow
            Spree.invoice_create_workflow
          end

          # The model keeps a credit note's original on the same order or
          # payout, whoever calls.
          def create_workflow_arguments
            { parent: @parent, attributes: permitted_params, uploaded_by: current_actor, issuer: acting_issuer }
          end

          # Who the caller issues as, or nil when the order decides (the
          # operator uploads for whoever sold the goods).
          def acting_issuer
            nil
          end
        end
      end
    end
  end
end
