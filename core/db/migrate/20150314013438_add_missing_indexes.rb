class AddMissingIndexes < ActiveRecord::Migration
  def change
    add_index   :spree_promotion_rules_users,
                        [:user_id, :promotion_rule_id],
                        name: 'index_promotion_rules_users_on_user_id_and_promotion_rule_id'
    add_index   :spree_products_promotion_rules,
                        [:promotion_rule_id, :product_id],
                        name: 'index_products_promotion_rules_on_promotion_rule_and_product'
    add_index :spree_orders, :canceler_id
    add_index :spree_orders, :store_id
    add_index :spree_orders_promotions, [:promotion_id, :order_id]
    add_index :spree_properties_prototypes, :prototype_id
    add_index   :spree_properties_prototypes,
                        [:prototype_id, :property_id],
                        name:  'index_properties_prototypes_on_prototype_and_property'
    add_index :spree_taxons_prototypes, [:prototype_id, :taxon_id]
    add_index :spree_option_types_prototypes, :prototype_id
    add_index   :spree_option_types_prototypes,
                        [:prototype_id, :option_type_id],
                        name: 'index_option_types_prototypes_on_prototype_and_option_type'
    add_index   :spree_option_values_variants,
                        [:option_value_id, :variant_id],
                        name: 'index_option_values_variants_on_option_value_and_variant'
  end
end
