class RemoveDuplicateIndexes < ActiveRecord::Migration[5.2]
  def change
    remove_index :spree_option_type_prototypes, name: "index_spree_option_type_prototypes_on_prototype_id"
    remove_index :spree_option_value_variants, name: "index_spree_option_value_variants_on_variant_id"
    remove_index :spree_order_promotions, name: "index_spree_order_promotions_on_promotion_id"
    remove_index :spree_prices, name: "index_spree_prices_on_variant_id"
    remove_index :spree_property_prototypes, name: "index_spree_property_prototypes_on_prototype_id"
    remove_index :spree_prototype_taxons, name: "index_spree_prototype_taxons_on_prototype_id"
    remove_index :spree_shipping_method_categories, name: "index_spree_shipping_method_categories_on_shipping_category_id"
    remove_index :spree_shipping_rates, name: "index_spree_shipping_rates_on_shipment_id"
    remove_index :spree_stock_items, name: "index_spree_stock_items_on_stock_location_id"
    remove_index :spree_taggings, name: "index_spree_taggings_on_tag_id"
    remove_index :spree_taggings, name: "index_spree_taggings_on_taggable_id"
    remove_index :spree_taggings, name: "index_spree_taggings_on_tagger_id"
  end
end
