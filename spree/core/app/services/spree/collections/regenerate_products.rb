module Spree
  module Collections
    class RegenerateProducts
      prepend ::Spree::ServiceModule::Base

      # Brings a collection's rule-derived membership up to date. Rows the
      # rules no longer match are removed and newly matched products are
      # appended; hand-picked rows are never touched, and excluded products
      # never stay. Surviving rows keep their positions, so a manual sort
      # order covers rule-derived and hand-picked products alike.
      #
      # @param collection [Spree::Collection]
      # @return [Spree::ServiceModule::Base::Result]
      def call(collection:)
        return if collection.nil?
        return if collection.destroyed?

        collection.claim_unknown_membership_sources!
        memberships = Spree::ProductCollection.where(collection_id: collection.id)
        sources = memberships.order(:position).pluck(:product_id, :source).to_h

        excluded_ids = collection.exclusions.pluck(:product_id)
        matched_ids = collection.products_matching_rules.where.not(id: excluded_ids).ids
        rule_ids = sources.reject { |_, source| source == 'manual' }.keys

        stale_ids = (rule_ids - matched_ids) | (sources.keys & excluded_ids)
        new_ids = matched_ids - sources.keys

        removed = []
        ApplicationRecord.transaction do
          removed = remove(memberships, stale_ids, excluded_ids)
          append(collection, memberships, new_ids)
        end

        refresh(collection, stale_ids + new_ids)
        publish_events(removed, 'deleted')
        publish_events(memberships.where(product_id: new_ids), 'created') if new_ids.any?
        success(collection)
      end

      private

      # Deletes the rows and closes the gaps they leave in the positions.
      # Excluded products go whatever their source; other stale rows only if
      # they are still rule rows, so a hand-pick made meanwhile survives.
      # Returns the deleted rows, held for their events.
      def remove(memberships, product_ids, excluded_ids)
        return [] if product_ids.empty?

        removed = memberships.where(product_id: product_ids & excluded_ids).
                  or(memberships.where(product_id: product_ids - excluded_ids).where.not(source: 'manual')).
                  order(:id).lock.to_a
        Spree::ProductCollection.where(id: removed.map(&:id)).delete_all
        now = Time.current
        remaining = memberships.order(:position).pluck(:collection_id, :product_id, :source)
        return removed if remaining.empty?

        rows = remaining.map.with_index(1) do |(collection_id, product_id, source), position|
          { collection_id: collection_id, product_id: product_id, source: source, position: position, created_at: now, updated_at: now }
        end
        Spree::ProductCollection.upsert_all(rows, unique_by: (%i[collection_id product_id] unless Spree.mysql?), update_only: %i[position])
        removed
      end

      def append(collection, memberships, product_ids)
        return if product_ids.empty?

        position = memberships.maximum(:position).to_i
        now = Time.current

        Spree::ProductCollection.insert_all(
          product_ids.map do |product_id|
            {
              collection_id: collection.id, product_id: product_id, source: 'rule',
              position: (position += 1), created_at: now, updated_at: now
            }
          end
        )
      end

      # Bulk writes skip the counter caches and touches, so they happen here.
      def refresh(collection, changed_product_ids)
        Spree::Collection.reset_counters(collection.id, :product_collections)
        return if changed_product_ids.empty?

        Spree::Product.reset_counters_in_bulk(changed_product_ids, :product_collections)
        products = Spree::Product.where(id: changed_product_ids)
        products.touch_all
        products.each(&:enqueue_search_index)
      end

      def publish_events(memberships, action)
        memberships = memberships.to_a
        return if memberships.empty?

        ActiveRecord::Associations::Preloader.new(records: memberships, associations: { product: :store }).call
        memberships.each { |membership| membership.publish_event("product_collection.#{action}") }
      end
    end
  end
end
