module Spree
  module Api
    module V3
      module Seller
        # The seller's view of an invoice on one of their orders, or of a
        # commission invoice the marketplace issued them.
        class InvoiceSerializer < Admin::InvoiceSerializer
          # The admin actor shape is not the seller branch's to publish.
          _attributes.delete(:order)
          _attributes.delete(:uploaded_by)

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
