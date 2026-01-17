module Spree
  module Storefront
    module PaginationConcern
      extend ActiveSupport::Concern

      included do
        include Pagy::Method
      end

      private

      def paginate_collection(collection, limit:)
        if Spree::Storefront::Config[:use_kaminari_pagination]
          collection.page(params[:page]).per(limit)
        else
          # Pre-compute count to avoid issues with complex ORDER BY clauses
          # that reference computed columns not available in the COUNT query
          count = pagy_get_count(collection)

          @pagy, records = pagy(:offset, collection, limit: limit, count: count)
          records
        end
      end

      # Get count for pagination, handling complex queries
      def pagy_get_count(collection)
        # Remove ordering and custom selects, then count distinct IDs
        count_scope = collection.reorder(nil).except(:select).select('1')
        count = count_scope.distinct.count
        count.is_a?(Hash) ? count.keys.size : count
      rescue StandardError => e
        Rails.logger.warn "Pagy count fallback: #{e.message}"
        # Last resort fallback - load count from the model
        begin
          collection.model.from(collection.except(:order).arel.as(collection.model.table_name)).count
        rescue StandardError
          0
        end
      end
    end
  end
end
