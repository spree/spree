class AddPerformedByToSpreeReimbursements < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_reimbursements, :performed_by_id, :bigint, index: true, null: true, if_not_exists: true
  end
end
