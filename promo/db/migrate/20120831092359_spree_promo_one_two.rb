class SpreePromoOneTwo < ActiveRecord::Migration
  def up
    create_table "spree_products_promotion_rules", :id => false, :force => true do |t|
      t.integer "product_id"
      t.integer "promotion_rule_id"
    end

    add_index "spree_products_promotion_rules", ["product_id"], :name => "index_products_promotion_rules_on_product_id"
    add_index "spree_products_promotion_rules", ["promotion_rule_id"], :name => "index_products_promotion_rules_on_promotion_rule_id"

    create_table "spree_promotion_action_line_items", :force => true do |t|
      t.integer "promotion_action_id"
      t.integer "variant_id"
      t.integer "quantity",            :default => 1
    end

    create_table "spree_promotion_actions", :force => true do |t|
      t.integer "activator_id"
      t.integer "position"
      t.string  "type"
    end

    create_table "spree_promotion_rules", :force => true do |t|
      t.integer  "activator_id"
      t.integer  "user_id"
      t.integer  "product_group_id"
      t.string   "type"
      t.timestamps
    end

    add_index "spree_promotion_rules", ["product_group_id"], :name => "index_promotion_rules_on_product_group_id"
    add_index "spree_promotion_rules", ["user_id"], :name => "index_promotion_rules_on_user_id"

    create_table "spree_promotion_rules_users", :id => false, :force => true do |t|
      t.integer "user_id"
      t.integer "promotion_rule_id"
    end

    add_index "spree_promotion_rules_users", ["promotion_rule_id"], :name => "index_promotion_rules_users_on_promotion_rule_id"
    add_index "spree_promotion_rules_users", ["user_id"], :name => "index_promotion_rules_users_on_user_id"
  end
end
