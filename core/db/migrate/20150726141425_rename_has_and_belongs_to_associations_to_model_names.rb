class RenameHasAndBelongsToAssociationsToModelNames < ActiveRecord::Migration
  def change
    {
      'spree_option_types_prototypes' => 'spree_option_type_prototypes',
      'spree_option_values_variants' => 'spree_option_value_variants',
      'spree_orders_promotions' => 'spree_order_promotions',
      'spree_products_promotion_rules' => 'spree_product_promotion_rules',
      'spree_taxons_promotion_rules' => 'spree_promotion_rule_taxons',
      'spree_promotion_rules_users' => 'spree_promotion_rule_users',
      'spree_properties_prototypes' => 'spree_property_prototypes',
      'spree_taxons_prototypes' => 'spree_prototype_taxons',
      'spree_roles_users' => 'spree_role_users',
      'spree_shipping_methods_zones' => 'spree_shipping_method_zones'
    }.each do |old_name, new_name|
      rename_table old_name, new_name
    end
  end
end
