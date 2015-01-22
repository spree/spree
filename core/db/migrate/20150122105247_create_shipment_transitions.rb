class CreateShipmentTransitions < ActiveRecord::Migration
  def change
    create_table :spree_shipment_transitions do |t|
      t.string :to_state, null: false
      t.text :metadata, default: "{}"
      t.integer :sort_key, null: false
      t.integer :shipment_id, null: false
      t.timestamps
    end

    add_index :spree_shipment_transitions, :shipment_id
    add_index :spree_shipment_transitions, [:sort_key, :shipment_id], unique: true
  end
end
