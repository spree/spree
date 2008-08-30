class RemoveCart < ActiveRecord::Migration
  def self.up
    drop_table :carts
    drop_table :cart_items
  end

  def self.down
    # No going back.
  end
end
