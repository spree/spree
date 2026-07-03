namespace :spree do
  desc <<~DESC
    Migrates products off the master variant. Idempotent (products that already
    have a default_variant_id are skipped) and loud about deletions.

    For each product:
      * With real variants: point default_variant_id at the first variant by
        position, then delete the now-empty master — unless it still carries
        line items, in which case keep it as a regular variant (is_master=false)
        so historical orders stay intact.
      * Simple (no-variant) products: convert the master into a regular variant
        (is_master=false) and point default_variant_id at it.
      * Recompute variant_count to the real variant count.

    Prerequisite: run +spree:media:migrate_master_images_to_product_media+ first
    so no master-pinned media is lost when ghost masters are deleted.
  DESC
  task remove_master_variant: :environment do
    migrated = converted = deleted = kept = 0

    # with_deleted: Product/Variant are paranoid, so soft-deleted rows would
    # otherwise be skipped and keep a NULL default_variant_id.
    Spree::Product.with_deleted.where(default_variant_id: nil).find_each do |product|
      master = Spree::Variant.where(product_id: product.id, is_master: true).first
      first_variant = Spree::Variant.where(product_id: product.id, is_master: false).order(:position).first

      if first_variant
        product.update_column(:default_variant_id, first_variant.id)

        if master && master.line_items.exists?
          master.update_column(:is_master, false)
          kept += 1
        elsif master
          Rails.logger.info("[remove_master_variant] deleting master variant #{master.id} of product #{product.id}")
          master.really_destroy!
          deleted += 1
        end
      elsif master
        master.update_column(:is_master, false)
        product.update_column(:default_variant_id, master.id)
        converted += 1
      else
        next
      end

      variant_count = Spree::Variant.where(product_id: product.id, deleted_at: nil).count
      product.update_column(:variant_count, variant_count)

      migrated += 1
    end

    puts "  Migrated #{migrated} product(s): converted #{converted} simple master(s), " \
         "deleted #{deleted} ghost master(s), kept #{kept} master(s) with order history."
  end
end
