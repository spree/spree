class AddDisplayToPaymentMethods < ActiveRecord::Migration
  def self.up
    add_column :payment_methods, :display, :string, :default => nil
  end

  def self.down
    remove_column :payment_methods, :display
  end
end
