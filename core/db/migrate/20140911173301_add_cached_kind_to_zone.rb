class AddCachedKindToZone < ActiveRecord::Migration
  def change
    add_column :spree_zones, :cached_kind, :string

    add_index :spree_zones, :cached_kind

    Spree::Zone.all.each { |zone| zone.set_cached_kind && zone.save! }
  end
end
