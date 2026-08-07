class AddUniqueStoreTypeIndexToSpreeIntegrations < ActiveRecord::Migration[7.2]
  def up
    # The model has always validated one integration per (store, type), but
    # without a backing index a race could have persisted duplicates. Keep the
    # oldest of each group so the index can be created.
    # Raw SQL, not the model — a migration must not depend on application
    # code that may not load at this revision.
    execute(<<~SQL)
      DELETE FROM spree_integrations
      WHERE id NOT IN (
        SELECT keeper FROM (
          SELECT MIN(id) AS keeper FROM spree_integrations GROUP BY store_id, type
        ) AS keepers
      )
    SQL

    add_index :spree_integrations, [:store_id, :type], unique: true,
              name: 'index_spree_integrations_on_store_id_and_type', if_not_exists: true
  end

  def down
    remove_index :spree_integrations, name: 'index_spree_integrations_on_store_id_and_type', if_exists: true
  end
end
