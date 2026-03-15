# frozen_string_literal: true

class CreateSpreeAllowedOrigins < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_allowed_origins do |t|
      t.references :store, null: false
      t.string :origin, null: false
      t.timestamps
    end

    add_index :spree_allowed_origins, [:store_id, :origin], unique: true,
              name: 'index_spree_allowed_origins_on_store_id_and_origin'
  end
end
