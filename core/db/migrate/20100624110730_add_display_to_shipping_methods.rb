class AddDisplayToShippingMethods < ActiveRecord::Migration
  def change
    add_column :shipping_methods, :display_on, :string, :default => nil
  end
end
