class RenamePaymentMethodDisplay < ActiveRecord::Migration
  def self.up
    rename_column :payment_methods, :display, :display_on
  end

  def self.down
    rename_column :payment_methods, :display_on, :display
  end
end