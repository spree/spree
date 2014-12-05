module Spree
  module AdjustmentSource
    extend ActiveSupport::Concern

    included do
      has_many :adjustments, as: :source
      before_destroy :deals_with_adjustments_for_deleted_source
      
      def deals_with_adjustments_for_deleted_source
        adjustment_scope = self.adjustments.includes(:order).references(:spree_orders)

        # For incomplete orders, remove the adjustment completely.
        adjustment_scope.where("spree_orders.completed_at IS NULL").destroy_all

        # For complete orders, the source will be invalid.
        # Therefore we nullify the source_id, leaving the adjustment in place.
        # This would mean that the order's total is not altered at all.
        adjustment_scope.where("spree_orders.completed_at IS NOT NULL").each do |adjustment|
          adjustment.update_columns(
            source_id: nil,
            updated_at: Time.now,
          )
        end
      end
    end
  end
end
