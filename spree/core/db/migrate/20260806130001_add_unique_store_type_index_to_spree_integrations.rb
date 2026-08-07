class AddUniqueStoreTypeIndexToSpreeIntegrations < ActiveRecord::Migration[7.2]
  def change
    # Backs the existing one-integration-per-(store, type) model validation.
    # No de-duplication step: core ships no Integration subclasses and none
    # were creatable before this release, so the table is empty everywhere.
    add_index :spree_integrations, [:store_id, :type], unique: true,
              name: 'index_spree_integrations_on_store_id_and_type', if_not_exists: true
  end
end
