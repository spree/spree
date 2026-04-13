class CreateSpreeCustomDomains < ActiveRecord::Migration[6.1]
  def change
    return if table_exists?(:spree_custom_domains)

    create_table :spree_custom_domains do |t|
      t.references :store, null: false, index: true
      t.string :url, null: false, index: { unique: true }
      t.boolean :status, default: false
      t.boolean :default, default: false, null: false

      if t.respond_to? :jsonb
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end
  end
end
