# This migration comes from spree (originally 20240915144935)
class AddPositionToSpreeProperties < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_properties, :position, :integer, default: 0, if_not_exists: true
    add_index :spree_properties, :position, if_not_exists: true
  end
end
