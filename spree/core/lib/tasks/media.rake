namespace :spree do
  namespace :media do
    desc 'Backfill primary_media_id for all variants and products'
    task backfill_primary_media: :environment do
      puts 'Backfilling variant primary_media...'
      Spree::Variant.where(primary_media_id: nil).where.not(media_count: 0).find_each do |variant|
        first_media = variant.gallery_media.first
        variant.update_column(:primary_media_id, first_media.id) if first_media
      end

      puts 'Backfilling product primary_media...'
      Spree::Product.where(primary_media_id: nil).where.not(media_count: 0).find_each do |product|
        first_media = product.gallery_media.first
        product.update_column(:primary_media_id, first_media.id) if first_media
      end

      puts 'Done!'
    end

    # Re-homes legacy variant-pinned images to the Product, and creates
    # VariantMedia rows for non-master variants so per-variant assignments
    # survive the move. If a variant has historical line items the asset is
    # copied (blob re-attached) instead of moved, preserving order history.
    # Master images become product-level with no VariantMedia rows — they apply
    # to all variants via gallery_media's fallback. Idempotent.
    desc 'Migrate legacy variant-pinned images to product-level media + VariantMedia (opt-in, 5.5)'
    task migrate_master_images_to_product_media: :environment do
      moved = 0
      copied = 0
      links_created = 0
      products_touched = 0

      move_or_copy = lambda do |asset, product, has_line_items|
        if has_line_items
          duplicate = asset.dup
          duplicate.viewable_type = 'Spree::Product'
          duplicate.viewable_id = product.id
          duplicate.attachment.attach(asset.attachment.blob) if asset.attachment.attached?
          duplicate.save!
          copied += 1
          duplicate
        else
          asset.update_columns(
            viewable_type: 'Spree::Product',
            viewable_id: product.id,
            updated_at: Time.current
          )
          moved += 1
          asset
        end
      end

      Spree::Product.includes(:master, :variants).find_each do |product|
        all_variant_ids = product.variants.map(&:id)
        all_variant_ids << product.master.id if product.master
        # One query per product to find variants with line items, instead of
        # one per variant in the loop.
        variants_with_line_items = Spree::LineItem.where(variant_id: all_variant_ids)
                                                  .distinct.pluck(:variant_id).to_set

        touched = 0

        product.variants.each do |variant|
          variant_assets = Spree::Asset.where(viewable_type: 'Spree::Variant', viewable_id: variant.id)
          next if variant_assets.empty?

          has_line_items = variants_with_line_items.include?(variant.id)

          variant_assets.find_each do |asset|
            target = move_or_copy.call(asset, product, has_line_items)
            link_attrs = { variant_id: variant.id, media_id: target.id }
            unless Spree::VariantMedia.exists?(link_attrs)
              Spree::VariantMedia.create!(link_attrs)
              links_created += 1
            end
            touched += 1
          end
        end

        master = product.master
        if master
          master_has_line_items = variants_with_line_items.include?(master.id)
          Spree::Asset.where(viewable_type: 'Spree::Variant', viewable_id: master.id).find_each do |asset|
            move_or_copy.call(asset, product, master_has_line_items)
            touched += 1
          end
        end

        next if touched.zero?

        products_touched += 1
        product.update_columns(
          media_count: product.media.count + product.variant_images_without_master.count,
          updated_at: Time.current
        )
        first_media = product.media.order(:position).first ||
                      product.variant_images_without_master.order(:position).first
        product.update_column(:primary_media_id, first_media&.id)
      end

      puts "Touched #{products_touched} products: moved #{moved} variant-pinned assets, " \
           "copied #{copied} (line items present), created #{links_created} variant↔asset links."
    end
  end
end
