class UpdatePositionField < ActiveRecord::Migration[5.1]
  def change
    %w(spree_assets spree_products_taxons spree_option_types
       spree_option_values spree_payment_methods spree_product_option_types
       spree_product_properties spree_taxonomies spree_variants).each do |table_name|
      ActiveRecord::Base.connection.execute("UPDATE #{table_name} SET position = position + 1")
    end
  end
end
