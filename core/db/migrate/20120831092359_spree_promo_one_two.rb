class SpreePromoOneTwo < ActiveRecord::Migration
  def up
    # This migration is just a compressed migration for all previous versions of spree_promo
    return if table_exists?(:spree_products_promotion_rules)

    create_table :spree_products_promotion_rules, :id => false, :force => true do |t|
      t.references :product
      t.references :promotion_rule
    end

    add_index :spree_products_promotion_rules, [:product_id], :name => 'index_products_promotion_rules_on_product_id'
    add_index :spree_products_promotion_rules, [:promotion_rule_id], :name => 'index_products_promotion_rules_on_promotion_rule_id'

    create_table :spree_promotion_action_line_items, :force => true do |t|
      t.references :promotion_action
      t.references :variant
      t.integer    :quantity,            :default => 1
    end

    create_table :spree_promotion_actions, :force => true do |t|
      t.references :activator
      t.integer    :position
      t.string     :type
    end

    create_table :spree_promotion_rules, :force => true do |t|
      t.references :activator
      t.references :user
      t.references :product_group
      t.string     :type
      t.timestamps null: false
    end

    add_index :spree_promotion_rules, [:product_group_id], :name => 'index_promotion_rules_on_product_group_id'
    add_index :spree_promotion_rules, [:user_id], :name => 'index_promotion_rules_on_user_id'

    create_table :spree_promotion_rules_users, :id => false, :force => true do |t|
      t.references :user
      t.references :promotion_rule
    end

    add_index :spree_promotion_rules_users, [:promotion_rule_id], :name => 'index_promotion_rules_users_on_promotion_rule_id'
    add_index :spree_promotion_rules_users, [:user_id], :name => 'index_promotion_rules_users_on_user_id'
  end
end
