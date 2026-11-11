module Spree
  module Api
    module V3
      # A buyer's request for an invoice, as the buyer sees it.
      class InvoiceRequestSerializer < BaseSerializer
        typelize status: [:string, enum: Spree::InvoiceRequest.statuses, enum_type_name: 'InvoiceRequestStatus'],
                 company_name: [:string, nullable: true],
                 tax_id: [:string, nullable: true],
                 order_id: :string,
                 invoice_id: [:string, nullable: true]

        attributes :status, :company_name, :tax_id

        prefixed_id_attributes :order, :invoice
      end
    end
  end
end
