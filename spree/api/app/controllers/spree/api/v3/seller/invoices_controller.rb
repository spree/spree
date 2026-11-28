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
            on_orders = base.where(order_id: current_seller_orders.select(:id))
            return on_orders.where(issuer: current_seller) if %w[destroy resend].include?(action_name)
            # Commission invoices are part of the seller's books, which their
            # earnings permission guards, not the orders one.
            return on_orders unless holds_permission?('read_seller_earnings')

            on_orders.or(base.where(seller_payout_id: current_seller.seller_payouts.select(:id)))
          end
        end
      end
    end
  end
end
