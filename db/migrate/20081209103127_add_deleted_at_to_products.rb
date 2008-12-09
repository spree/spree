class AddDeletedAtToProducts < ActiveRecord::Migration
  def self.up
    add_column :products, :deleted_at, :timestamp
    add_column :variants, :deleted_at, :timestamp
  end

  def self.down
    remove_column :products, :deleted_at
    remove_column :variants, :deleted_at
  end
end
