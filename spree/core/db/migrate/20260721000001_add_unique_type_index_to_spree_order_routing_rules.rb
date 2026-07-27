class AddUniqueTypeIndexToSpreeOrderRoutingRules < ActiveRecord::Migration[7.2]
  def change
    add_index :spree_order_routing_rules, [:channel_id, :type],
              unique: true,
              name: 'idx_order_routing_rules_channel_type'
  end
end
