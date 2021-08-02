class AddMissingTimestampColumns < ActiveRecord::Migration[5.2]
  def change
    # Add missing created_at columns
    %i[
      spree_countries
      spree_option_type_prototypes
      spree_option_value_variants
      spree_order_promotions
      spree_product_promotion_rules
      spree_products_taxons
      spree_promotion_action_line_items
      spree_promotion_actions
      spree_promotion_rule_taxons
      spree_promotion_rule_users
      spree_property_prototypes
      spree_prototype_taxons
      spree_reimbursement_credits
      spree_role_users
      spree_roles
      spree_shipping_method_zones
      spree_states
    ].each do |table|
      add_column table, :created_at, :datetime unless column_exists?(table, :created_at)
    end
    # Add missing updated_at columns
    %i[
      spree_option_type_prototypes
      spree_option_value_variants
      spree_order_promotions
      spree_product_promotion_rules
      spree_products_taxons
      spree_promotion_action_line_items
      spree_promotion_actions
      spree_promotion_rule_taxons
      spree_promotion_rule_users
      spree_property_prototypes
      spree_prototype_taxons
      spree_reimbursement_credits
      spree_role_users
      spree_roles
      spree_shipping_method_zones
    ].each do |table|
      add_column table, :updated_at, :datetime unless column_exists?(table, :updated_at)
    end
  end
end
