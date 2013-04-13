class ChangeSpreePaymentsAmountPrecision < ActiveRecord::Migration
  def change
   
    change_column :spree_payments, :amount,  :decimal, :precision => 10, :scale => 2, :default => 0.0, :null => false
                                   
  end
end
