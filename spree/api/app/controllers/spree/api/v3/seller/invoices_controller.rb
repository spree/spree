module Spree
  module Api
    module V3
      module Seller
        # Invoices issued in this seller's name, and the commission invoices the
        # marketplace issued them. A seller may delete or resend only their own:
        # commission invoices, and the store's invoices for a platform-remitted
        # seller, are the marketplace's documents.
        class InvoicesController < Seller::ResourceController
          include Spree::Api::V3::InvoiceMemberActions

          scoped_resource :orders

          protected

          def serializer_class
            Spree.api.seller_invoice_serializer
          end

          def scope
            base = Spree::Invoice.for_store(current_store)
            own = base.where(issuer: current_seller, order_id: current_seller_orders.select(:id))
            return own if %w[destroy resend].include?(action_name)

            own.or(base.where(seller_payout_id: current_seller.seller_payouts.select(:id)))
          end
        end
      end
    end
  end
end
