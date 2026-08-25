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

    # No column moves: the company tree migration (20260807000001) is born
    # without external_id — ERP/CRM identity lives here from the start.
  end
end
