class AddDisplayToShippingMethods < ActiveRecord::Migration
  def self.up
    add_column :shipping_methods, :display_on, :string, :default => nil
  end

  def self.down
    remove_column :shipping_methods, :display_on
  end
end
