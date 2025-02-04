module Spree
  module Reports
    class SalesTotal < Spree::Report
      def line_items_scope
        store.line_items.where(
          order: Spree::Order.complete.where(
            currency: currency,
            completed_at: (date_from.to_time.beginning_of_day)..(date_to.to_time.end_of_day)
          )
        ).includes(:order, variant: :product)
      end
    end
  end
end
