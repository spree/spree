class AddTrackInventoryToVariant < ActiveRecord::Migration[4.2]
  def change
    add_column :spree_variants, :track_inventory, :boolean, default: true
  end
end
