module Spree
  module Api
    module V3
      module Seller
        # Invoices on this seller's orders, and the commission invoices the
        # marketplace issued them. A seller may delete or resend only the
        # invoices on their own orders: commission invoices are the
        # marketplace's documents.
        class InvoicesController < Seller::ResourceController
          include Spree::Api::V3::InvoiceMemberActions

          scoped_resource :orders

          protected

          def serializer_class
            Spree.api.seller_invoice_serializer
          end

          def scope
            base = Spree::Invoice.for_store(current_store)
            visible = base.where(order_id: current_seller_orders.select(:id))
            return visible if %w[destroy resend].include?(action_name)

            visible.or(base.where(seller_payout_id: current_seller.seller_payouts.select(:id)))
          end
        end
      end
    end
  end
end
