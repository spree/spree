class AddTrackInventoryToVariant < ActiveRecord::Migration
  def change
    add_column :spree_variants, :track_inventory, :boolean, :default => true
  end
end
