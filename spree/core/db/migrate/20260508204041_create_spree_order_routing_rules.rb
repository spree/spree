class CreateSpreeOrderRoutingRules < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_order_routing_rules, if_not_exists: true do |t|
      t.references :store, null: false
      t.references :channel, null: false
      t.string :type, null: false
      t.integer :position, null: false
      t.boolean :active, null: false
      t.text :preferences
      t.timestamps
    end

    add_index :spree_order_routing_rules, [:channel_id, :position], if_not_exists: true
    add_index :spree_order_routing_rules, [:channel_id, :active, :position],
              name: 'idx_order_routing_rules_lookup', if_not_exists: true
    add_index :spree_order_routing_rules, :type, if_not_exists: true
  end
end
