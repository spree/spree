class CreateSpreeSavedReports < ActiveRecord::Migration[8.1]
  INDEX_NAME = 'index_spree_saved_reports_on_store_and_lower_name'.freeze

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

    add_name_uniqueness_index
  end

  private

  # One report per name per store, compared case-insensitively so it matches
  # the model's validation and the seeder's idempotency check — both of which
  # already downcase. A case-sensitive index lets "Top products" and
  # "top products" both land, which is exactly the pair re-seeding produces.
  #
  # Written per adapter because MySQL and MariaDB reject the functional-index
  # syntax PostgreSQL and SQLite accept; they index a stored generated column
  # instead. Expression per the spree_price_lists precedent.
  def add_name_uniqueness_index
    if Spree.mysql?
      reversible do |dir|
        dir.up do
          execute <<~SQL.squish
            ALTER TABLE spree_saved_reports
            ADD COLUMN name_key VARCHAR(255)
            AS (LOWER(name)) STORED
          SQL
          add_index :spree_saved_reports, [:store_id, :name_key], unique: true, name: INDEX_NAME
        end

        dir.down do
          remove_index :spree_saved_reports, name: INDEX_NAME
          remove_column :spree_saved_reports, :name_key
        end
      end
    else
      add_index :spree_saved_reports, 'store_id, LOWER(name)', unique: true, name: INDEX_NAME
    end
  end
end
