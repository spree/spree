module Spree
  module Media
    # Per-product worker for the 5.4 → 5.5 media migration. Idempotent.
    class MigrateProductAssetsJob < Spree::BaseJob
      queue_as Spree.queues.images

      def perform(product_id)
        product = Spree::Product.includes(:master, :variants).find_by(id: product_id)
        return unless product

        # One query for all variant-pinned assets on the product (master +
        # non-master). Grouping by viewable_id avoids N queries per variant.
        viewable_ids = product.variants.map(&:id)
        viewable_ids << product.master.id if product.master
        return if viewable_ids.empty?

        assets_by_variant = Spree::Asset
                              .where(viewable_type: 'Spree::Variant', viewable_id: viewable_ids)
                              .pluck(:id, :viewable_id)
                              .group_by(&:last)
                              .transform_values { |rows| rows.map(&:first) }
        return if assets_by_variant.empty?

        master_id = product.master&.id
        touched_variants = []

        product.variants.each do |variant|
          asset_ids = assets_by_variant[variant.id]
          next if asset_ids.blank?

          move_assets_to_product(asset_ids, product)
          link_assets_to_variant(asset_ids, variant.id)
          touched_variants << variant
        end

        if master_id && (master_asset_ids = assets_by_variant[master_id]).present?
          move_assets_to_product(master_asset_ids, product)
          touched_variants << product.master
        end

        # update_all + upsert_all skip callbacks, so refresh thumbnails by hand.
        touched_variants.each(&:update_thumbnail!)
        recalculate_counters(product)
      end

      private

      def move_assets_to_product(asset_ids, product)
        Spree::Asset.where(id: asset_ids).update_all(
          viewable_type: 'Spree::Product',
          viewable_id: product.id,
          updated_at: Time.current
        )
      end

      def link_assets_to_variant(asset_ids, variant_id)
        rows = asset_ids.map { |asset_id| { variant_id: variant_id, media_id: asset_id } }

        # MySQL infers the conflict target from the unique index; only PG/SQLite
        # need the explicit `unique_by:`.
        opts = { on_duplicate: :skip }
        if %w[PostgreSQL SQLite].include?(ActiveRecord::Base.connection.adapter_name)
          opts[:unique_by] = :idx_variant_media_unique
        end

        Spree::VariantMedia.upsert_all(rows, **opts)
      end

      def recalculate_counters(product)
        new_count = product.media.count
        new_primary_id = product.media.order(:position).pick(:id)

        return if product.media_count == new_count && product.primary_media_id == new_primary_id

        product.update_columns(
          media_count: new_count,
          primary_media_id: new_primary_id,
          updated_at: Time.current
        )
      end
    end
  end
end
