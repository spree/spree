module Spree
  module Api
    module V3
      module Admin
        # What the marketplace actually earned, sale by sale.
        #
        # Read-only, enforced by the routes: a commission line records
        # something that already happened, frozen when the order was placed.
        # Correcting one is not an edit but a reversal, which arrives with
        # refunds in the next phase.
        class CommissionLinesController < ResourceController
          scoped_resource :commissions

          protected

          def model_class
            Spree::CommissionLine
          end

          def serializer_class
            Spree.api.admin_commission_line_serializer
          end

          # Reached through the store's own orders: the lines carry no store of
          # their own, and the order is what ties them to one.
          def scope
            super.where(order_id: current_store.orders.select(:id))
          end

          def collection_includes
            [:vendor, :commission_rate, :order]
          end
        end
      end
    end
  end
end
