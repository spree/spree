# This migration comes from spree (originally 20251222000000)
class AddPerformanceIndexesToSpreeAdjustments < ActiveRecord::Migration[7.2]
  def change
    # Composite index for filtering adjustments by order, type and eligibility
    # Used in OrderUpdater#update_adjustment_total when summing eligible adjustments
    # and filtering by source_type (e.g., promotion adjustments)
    add_index :spree_adjustments,
              [:order_id, :eligible, :source_type],
              name: 'index_spree_adjustments_on_order_eligible_source_type',
              if_not_exists: true

    # Composite index for AdjustmentsUpdater queries that filter by adjustable and source type
    # Used when recalculating tax and promotion adjustments for a specific adjustable
    add_index :spree_adjustments,
              [:adjustable_type, :adjustable_id, :source_type],
              name: 'index_spree_adjustments_on_adjustable_and_source_type',
              if_not_exists: true

    # Index for state-based filtering (open/closed adjustments)
    # Used in Adjustment.not_finalized and Adjustment.finalized scopes
    add_index :spree_adjustments,
              [:order_id, :state],
              name: 'index_spree_adjustments_on_order_id_and_state',
              if_not_exists: true
  end
end
