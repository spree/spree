class AddDisplayToPaymentMethods < ActiveRecord::Migration
  def change
    add_column :payment_methods, :display, :string, :default => nil
  end
end
