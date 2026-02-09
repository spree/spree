# This migration comes from spree (originally 20250119165904)
class CreateSpreeCustomDomains < ActiveRecord::Migration[6.1]
  def change
    return if table_exists?(:spree_custom_domains)

    create_table :spree_custom_domains do |t|
      t.references :store, null: false, index: true
      t.string :url, null: false, index: { unique: true }
      t.boolean :status, default: false
      t.boolean :default, default: false, null: false

      if t.respond_to? :jsonb
        t.jsonb :public_metadata
        t.jsonb :private_metadata
      else
        t.json :public_metadata
        t.json :private_metadata
      end

      t.timestamps
    end
  end
end
