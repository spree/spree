class ShippingMethodIdForCheckouts < ActiveRecord::Migration
  def self.up
    add_column "checkouts", "shipping_method_id", :integer
  end

  def self.down
    remove_column "checkouts", "shipping_method_id"
  end
end
