class AddLowerSlugIndexOnSpreeProducts < ActiveRecord::Migration[5.2]
  def change
    add_index :spree_products, 'lower(slug)', name: 'index_spree_products_on_lower_slug' unless index_exists?(:spree_products, 'index_spree_products_on_lower_slug')
  end
end
