module Spree
  module Reports
    class SalesTotal < Spree::Report
      def line_items_scope
        scope = store.line_items.where(
          order: Spree::Order.complete.where(
            currency: currency,
            completed_at: date_from..date_to
          )
        ).includes(:order, shipments: :inventory_units, variant: :product)

        scope = scope.where(seller_id: seller.id) if defined?(seller) && seller.present?

        scope
      end
    end
  end
end
