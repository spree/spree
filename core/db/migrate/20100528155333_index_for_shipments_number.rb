class IndexForShipmentsNumber < ActiveRecord::Migration
  def change
    add_index :shipments, :number
  end
end
