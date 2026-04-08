class AddUniqueIndexToSpreeZoneMembers < ActiveRecord::Migration[7.2]
  def up
    # Remove duplicate zone members, keeping the oldest record
    # Uses derived table for MySQL compatibility
    execute <<~SQL
      DELETE FROM spree_zone_members
      WHERE id NOT IN (
        SELECT min_id FROM (
          SELECT MIN(id) AS min_id
          FROM spree_zone_members
          GROUP BY zone_id, zoneable_type, zoneable_id
        ) AS keeper_ids
      )
    SQL

    remove_index :spree_zone_members, [:zoneable_id, :zoneable_type],
                 name: 'index_spree_zone_members_on_zoneable_id_and_zoneable_type',
                 if_exists: true

    add_index :spree_zone_members, [:zone_id, :zoneable_type, :zoneable_id],
              unique: true,
              name: 'index_spree_zone_members_uniqueness'
  end

  def down
    remove_index :spree_zone_members, name: 'index_spree_zone_members_uniqueness', if_exists: true

    add_index :spree_zone_members, [:zoneable_id, :zoneable_type],
              name: 'index_spree_zone_members_on_zoneable_id_and_zoneable_type'
  end
end
