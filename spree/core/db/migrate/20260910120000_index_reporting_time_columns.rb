class IndexReportingTimeColumns < ActiveRecord::Migration[8.1]
  # The payments and inventory reporting bases filter on these columns and
  # nothing else (docs/plans/6.0-analytics-semantic-layer.md). Movements are
  # the highest-volume table a mature store has and carry no store column, so
  # tenancy is a join up to the product — the composite serves that nested loop
  # and the date filter together, rather than leaving the planner to scan the
  # whole ledger.
  def change
    add_index :spree_stock_movements, %i[stock_level_id created_at]
    add_index :spree_payments, :created_at
  end
end
