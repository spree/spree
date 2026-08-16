class CreateSpreeUpgradeRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_upgrade_records do |t|
      # The release boundary this installation has completed the data steps
      # for — "5.6" means every manifest up to and including 5.5 → 5.6 is done.
      t.string :version, null: false
      # How we know: `walk` (a successful upgrade walk), `install` (a fresh
      # install, which needs no historical steps) or `manual`.
      t.string :source, null: false
      t.datetime :completed_at, null: false

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    add_index :spree_upgrade_records, :version, unique: true
  end
end
