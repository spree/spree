class CreateSpreeReimbursements < ActiveRecord::Migration
  def change
    create_table :spree_reimbursements do |t|
      t.string :number
      t.string :reimbursement_status
      t.integer :customer_return_id
      t.integer :order_id
      t.decimal :total, precision: 10, scale: 2

      t.timestamps null: false
    end

    add_index :spree_reimbursements, :customer_return_id
    add_index :spree_reimbursements, :order_id

    remove_column :spree_refunds, :customer_return_id, :integer
    add_column :spree_refunds, :reimbursement_id, :integer

    add_column :spree_return_items, :reimbursement_id, :integer
  end
end
