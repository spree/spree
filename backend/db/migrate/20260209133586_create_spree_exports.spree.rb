# This migration comes from spree (originally 20241030134309)
class CreateSpreeExports < ActiveRecord::Migration[6.1]
  def change
    return if table_exists?(:spree_exports)

    create_table :spree_exports do |t|
      t.references :user
      t.references :store, null: false

      t.string :number, limit: 32, null: false, index: { unique: true }
      t.string :type, null: false

      if t.respond_to? :jsonb
        t.jsonb :search_params
      else
        t.json :search_params
      end

      t.integer :format, index: true, null: false

      t.timestamps
    end
  end
end
