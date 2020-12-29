class AddTypeToReimbursementType < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_reimbursement_types, :type, :string
    add_index :spree_reimbursement_types, :type

    Spree::ReimbursementType.reset_column_information
    Spree::ReimbursementType.find_by(name: Spree::ReimbursementType::ORIGINAL).update!(type: 'Spree::ReimbursementType::OriginalPayment')
  end
end
