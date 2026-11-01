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
            include ActiveStorage::SetCurrent

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

          def create_workflow_arguments
            { parent: @parent, attributes: invoice_attributes, uploaded_by: current_actor }
          end

          private

          # The original invoice is read through the parent, so an id from
          # another order or payout is a 404 rather than a cross-link.
          def invoice_attributes
            attributes = params.permit(*declared_permitted_attributes).to_h
            original_id = attributes.delete('original_invoice_id')
            attributes['original_invoice'] = @parent.invoices.find_by_prefix_id!(original_id) if original_id.present?
            attributes
          end
        end
      end
    end
  end
end
