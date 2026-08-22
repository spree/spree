class CreateSpreeExternalReferences < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_external_references do |t|
      t.references :store, null: false, index: false
      t.string :system, null: false
      t.references :resource, polymorphic: true, null: false, index: false
      t.string :external_id, null: false
      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end
      t.timestamps
    end

    # One reference per system per record.
    add_index :spree_external_references,
              [:store_id, :system, :resource_type, :resource_id],
              unique: true, name: 'idx_external_references_on_resource'

    # An external id maps to exactly one record — what makes upsert-by-external-id safe.
    add_index :spree_external_references,
              [:store_id, :system, :resource_type, :external_id],
              unique: true, name: 'idx_external_references_on_external_id'

    # Reverse lookup for the resource-side association (resource → its references).
    add_index :spree_external_references, [:resource_type, :resource_id],
              name: 'idx_external_references_on_resource_lookup'

    # Company and location external ids move to the new table. Unreleased
    # (6.0-dev only), so no data carry-over: dev databases re-key from their
    # feed. Options given in full so the migration reverses cleanly.
    remove_index :spree_companies, [:store_id, :external_id], unique: true,
                 where: 'external_id IS NOT NULL', name: 'idx_companies_external_id'
    remove_column :spree_companies, :external_id, :string
    remove_column :spree_company_locations, :external_id, :string
  end
end
