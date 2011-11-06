class ChangePaymentsPaymentMethodToBelongsTo < ActiveRecord::Migration
  def up
    remove_column :payments, :payment_method
    add_column    :payments, :payment_method_id, :integer
  end

  def down
    add_column    :payments, :payment_method, :string
    remove_column :payments, :payment_method_id
  end
end
