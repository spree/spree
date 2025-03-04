class AddPerformedByToSpreeReimbursements < ActiveRecord::Migration[6.1]
  def change
    add_reference :spree_reimbursements, :performed_by, index: true, null: true
  end
end
