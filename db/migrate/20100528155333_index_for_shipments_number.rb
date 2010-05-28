class IndexForShipmentsNumber < ActiveRecord::Migration
  def self.up
    add_index :shipments, :number
  end

  def self.down
    remove_index :shipments, :number
  end
end
