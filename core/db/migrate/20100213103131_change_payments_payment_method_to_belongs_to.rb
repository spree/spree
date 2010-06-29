class ChangePaymentsPaymentMethodToBelongsTo < ActiveRecord::Migration
  def self.up
    remove_column "payments", "payment_method"
    add_column "payments", "payment_method_id", :integer
  end

  def self.down
    add_column "payments", "payment_method", :string
    remove_column "payments", "payment_method_id"
  end
end
