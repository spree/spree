class MigrateImagesFromProductsToVariants < ActiveRecord::Migration
  def up
    images = select_all("SELECT spree_assets.* FROM spree_assets
                         WHERE spree_assets.type IN ('Spree::Image')
                         AND spree_assets.viewable_type = 'Spree::Product'")

    images.each do |image|
      master_variant_id = select_value("SELECT id FROM spree_variants
                                        WHERE product_id = #{image['viewable_id']}
                                        AND is_master = 't'")

      execute("UPDATE spree_assets SET viewable_type = 'Spree::Variant', viewable_id = #{master_variant_id}
               WHERE id = #{image['id']}") if master_variant_id
    end
  end

  def down
    images = select_all("SELECT spree_assets.* FROM spree_assets
                         JOIN spree_variants
                         ON spree_variants.id = spree_assets.viewable_id
                         AND spree_variants.is_master = 't'
                         WHERE spree_assets.type IN ('Spree::Image')
                         AND spree_assets.viewable_type = 'Spree::Variant'")

    images.each do |image|
      product_id = select_value("SELECT spree_products.id FROM spree_products
                                 JOIN spree_variants
                                 ON spree_variants.id = #{image['viewable_id']}
                                 AND spree_products.id = spree_variants.product_id")

      execute("UPDATE spree_assets SET viewable_type = 'Spree::Product', viewable_id = #{product_id}
               WHERE id = #{image['id']}") if product_id
    end
  end
end
