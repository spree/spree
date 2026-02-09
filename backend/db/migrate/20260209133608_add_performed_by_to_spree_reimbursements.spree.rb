# This migration comes from spree (originally 20250304115943)
class AddPerformedByToSpreeReimbursements < ActiveRecord::Migration[6.1]
  def change
    add_reference :spree_reimbursements, :performed_by, index: true, null: true unless column_exists?(:spree_reimbursements, :performed_by_id)
  end
end
