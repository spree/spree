class AddIndexesToReimbursementCredits < ActiveRecord::Migration[5.0]
  def change
    add_index :spree_reimbursement_credits, :reimbursement_id
    add_index :spree_reimbursement_credits, [:creditable_id, :creditable_type], name: 'index_reimbursement_credits_on_creditable_id_and_type'
  end
end
