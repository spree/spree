class CreateSpreeOrderRoutingRules < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_order_routing_rules do |t|
      t.references :store, null: false
      t.references :channel, null: false
      t.string :type, null: false
      t.integer :position, null: false
      t.boolean :active, null: false
      t.text :preferences
      t.timestamps
    end

    add_index :spree_order_routing_rules, [:channel_id, :position]
    add_index :spree_order_routing_rules, [:channel_id, :active, :position],
              name: 'idx_order_routing_rules_lookup'
    add_index :spree_order_routing_rules, :type
  end
end
