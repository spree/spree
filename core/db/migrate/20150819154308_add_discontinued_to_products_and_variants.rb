class AddDiscontinuedToProductsAndVariants < ActiveRecord::Migration[4.2]
  def up
    add_column :spree_products, :discontinue_on, :datetime, after: :available_on
    add_column :spree_variants, :discontinue_on, :datetime, after: :deleted_at

    add_index :spree_products, :discontinue_on
    add_index :spree_variants, :discontinue_on

    puts "Warning: This migration changes the meaning of 'deleted'. Before this change, 'deleted' meant products that were no longer being sold in your store. After this change, you can only delete a product or variant if it has not already been sold to a customer (a model-level check enforces this). Instead, you should use the new field 'discontinue_on' for products or variants which were sold in the past but no longer for sale. This fixes bugs when other objects are attached to deleted products and variants. (Even though acts_as_paranoid gem keeps the records in the database, most associations are automatically scoped to exclude the deleted records.) In thew meaning of 'deleted,' you can still use the delete function on products & variants which are *truly user-error mistakes*, specifically before an order has been placed or the items have gone on sale. You also must use the soft-delete function (which still works after this change) to clean up slug (product) and SKU (variant) duplicates. Otherwise, you should generally over ever need to discontinue products.

Data Fix: We will attempt to reverse engineer the old meaning of 'deleted' (no longer for sale) to the new database field 'discontinue_on'. However, since Slugs and SKUs cannot be duplicated on Products and Variants, we cannot gaurantee this to be foolproof if you have deteled Products and Variants that have duplicate Slugs or SKUs in non-deleted records. In these cases, we recommend you use the additional rake task to clean up your old records (see rake db:fix_orphan_line_items). If you have such records, this migration will leave them in place, preferring the non-deleted records over the deleted ones. However, since old line items will still be associated with deleted objects, you will still the bugs in your app until you run:

rake db:fix_orphan_line_items

We will print out a report of the data we are fixing now: "

    Spree::Product.only_deleted.each do |product|
      # determine if there is a slug duplicate
      the_dup = Spree::Product.find_by(slug: product.slug)
      if the_dup.nil?
        # check to see if there are line items attached to any variants
        if Spree::Variant.with_deleted.where(product_id: product.id).map(&:line_items).any?
          puts "recovering deleted product id #{product.id} ... this will un-delete the record and set it to be discontinued"

          old_deleted = product.deleted_at
          product.update_column(:deleted_at, nil) # for some reason .recover doesn't appear to be a method
          product.update_column(:discontinue_on, old_deleted)
        else
          puts "leaving product id #{product.id} deleted because there are no line items attached to it..."
        end
      else
        puts "leaving product id #{product.id} deleted because there is a duplicate slug for '#{product.slug}' (product id #{the_dup.id}) "
        if product.variants.map(&:line_items).any?
          puts "WARNING: You may still have bugs with product id #{product.id} (#{product.name}) until you run rake db:fix_orphan_line_items"
        end
      end
    end

    Spree::Variant.only_deleted.each do |variant|
      # determine if there is a slug duplicate
      the_dup = Spree::Variant.find_by(sku: variant.sku)
      if the_dup.nil?
        # check to see if there are line items attached to any variants
        if variant.line_items.any?
          puts "recovering deleted variant id #{variant.id} ... this will un-delete the record and set it to be discontinued"
          old_deleted = variant.deleted_at
          variant.update_column(:deleted_at, nil) # for some reason .recover doesn't appear to be a method
          variant.update_column(:discontinue_on, old_deleted)
        else
          puts "leaving variant id #{variant.id} deleted because there are no line items attached to it..."
        end
      else
        puts "leaving variant id #{variant.id} deleted because there is a duplicate SKU for '#{variant.sku}' (variant id #{the_dup.id}) "
        if variant.line_items.any?
          puts "WARNING: You may still have bugs with variant id #{variant.id} (#{variant.name}) until you run rake db:fix_orphan_line_items"
        end
      end
    end
  end

  def down
    execute "UPDATE spree_products SET deleted_at = discontinue_on WHERE deleted_at IS NULL"
    execute "UPDATE spree_variants SET deleted_at = discontinue_on WHERE deleted_at IS NULL"

    remove_column :spree_products, :discontinue_on
    remove_column :spree_variants, :discontinue_on
  end
end
