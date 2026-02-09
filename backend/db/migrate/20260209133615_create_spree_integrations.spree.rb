# This migration comes from spree (originally 20250407085228)
class CreateSpreeIntegrations < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_integrations, if_not_exists: true do |t|
      t.references :store, null: false, index: true
      t.string :type, null: false, index: true
      t.text :preferences
      t.boolean :active, default: false, null: false, index: true

      t.timestamps
    end
  end
end
