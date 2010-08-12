class PaymentsStateAndAssignedToOrderOnly < ActiveRecord::Migration
  def self.up
    # TODO: migrate existing payments
    rename_column :payments, :payable_id, :order_id
    remove_column :payments, :payable_type
    add_column :payments, :state, :string
  end

  def self.down
  end
end
