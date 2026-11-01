module Spree
  module Api
    module V3
      module Seller
        # The seller's view of an invoice on one of their orders, or of a
        # commission invoice the marketplace issued them.
        class InvoiceSerializer < Admin::InvoiceSerializer
          # Who uploaded it is the operator's business: an admin user or an API
          # key is not the seller's to know.
          _attributes.delete(:order)
          _attributes.delete(:uploaded_by)
          _attributes.delete(:uploaded_by_id)
          _attributes.delete(:uploaded_by_type)

          attribute :can_be_deleted do |invoice|
            invoice.order_id.present? && invoice.can_be_deleted?
          end

          attribute :download_url do |invoice|
            next nil unless invoice.file.attached?

            Spree::Core::Engine.routes.url_helpers.download_api_v3_seller_invoice_path(id: invoice.prefixed_id)
          end
        end
      end
    end
  end
end
