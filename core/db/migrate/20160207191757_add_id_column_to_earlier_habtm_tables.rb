class AddIdColumnToEarlierHabtmTables < ActiveRecord::Migration[4.2]
  def up
    add_column :spree_option_type_prototypes, :id, :primary_key
    add_column :spree_option_value_variants, :id, :primary_key
    add_column :spree_order_promotions, :id, :primary_key
    add_column :spree_product_promotion_rules, :id, :primary_key
    add_column :spree_promotion_rule_users, :id, :primary_key
    add_column :spree_property_prototypes, :id, :primary_key
    add_column :spree_role_users, :id, :primary_key
    add_column :spree_shipping_method_zones, :id, :primary_key
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
