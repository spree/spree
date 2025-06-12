class CreateSpreeImports < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_imports do |t|
      t.references :user, null: true, foreign_key: { to_table: 'spree_users' }, index: true
      t.references :store, null: false, foreign_key: { to_table: 'spree_stores' }, index: true
      t.string :type, null: :false
      t.json :error_details, default: {}, null: false
      t.integer :processed_count
      t.integer :total_count
      t.datetime :processed_at
      
      t.timestamps null: false
    end
  end
end
