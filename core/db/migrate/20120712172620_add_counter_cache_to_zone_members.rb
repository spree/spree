class AddCounterCacheToZoneMembers < ActiveRecord::Migration
  def up
    add_column :spree_zones, :zone_members_count, :integer, :default => 0

    Spree::Zone.reset_column_information
    Spree::Zone.find(:all).each do |zone|
      Spree::Zone.update_counters zone.id, :zone_members_count => zone.zone_members.length
    end
  end

  def down
    remove_column :spree_zones, :zone_members_count
  end
end
