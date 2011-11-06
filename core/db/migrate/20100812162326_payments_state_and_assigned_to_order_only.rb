class PaymentsStateAndAssignedToOrderOnly < ActiveRecord::Migration
  def up
    # TODO: migrate existing payments
    rename_column :payments, :payable_id, :order_id
    remove_column :payments, :payable_type
    add_column :payments, :state, :string
  end

  def down
    remove_column :payments, :state
    add_column :payments, :payable_type, :string
    rename_column :payments, :order_id, :payable_id
  end
end
