class CreateSpreeNumberSequences < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_number_sequences do |t|
      t.references :store, null: false
      t.string :resource_type, null: false
      t.bigint :value, null: false, default: 0
      t.timestamps
    end

    add_index :spree_number_sequences, [:store_id, :resource_type],
              unique: true, name: 'index_spree_number_sequences_on_store_and_resource'
  end
end
