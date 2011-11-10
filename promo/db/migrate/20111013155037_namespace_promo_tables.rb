class NamespacePromoTables < ActiveRecord::Migration
  def change
    rename_table :promotion_actions, :spree_promotion_actions
    rename_table :promotion_rules, :spree_promotion_rules
    rename_table :promotion_rules_users, :spree_promotion_rules_users
    rename_table :promotion_action_line_items, :spree_promotion_action_line_items
    rename_table :products_promotion_rules, :spree_products_promotion_rules
  end
end
