class AddUniqueIndexOnPaymentNumber < ActiveRecord::Migration
  def change
    add_index :spree_payments, :number, unique: true
  end
end
