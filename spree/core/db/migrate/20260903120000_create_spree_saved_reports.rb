class CreateSpreeSavedReports < ActiveRecord::Migration[8.1]
  # docs/plans/6.0-analytics-semantic-layer.md — a saved report is a reporting
  # contract query owned by the store and shared with every staff member who
  # may read reports; its visualization is inferred from the query's shape.
  def change
    create_table :spree_saved_reports do |t|
      # No standalone store index: the unique [store_id, name] index leads with it.
      t.belongs_to :store, null: false, foreign_key: false, index: false
      t.belongs_to :user, foreign_key: false, index: true
      t.string :name, null: false
      t.text :description
      if t.respond_to?(:jsonb)
        t.jsonb :query, null: false
      else
        t.json :query, null: false
      end
      t.boolean :seeded, null: false, default: false
      t.timestamps
    end

    add_index :spree_saved_reports, [:store_id, :name], unique: true
  end
end
