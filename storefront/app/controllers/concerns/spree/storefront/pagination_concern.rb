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
          sql = collection.to_sql
          has_grouping = sql.include?(' HAVING ') || sql.include?(' GROUP BY ')

          if has_grouping
            # For queries with GROUP BY/HAVING, we need to provide explicit count
            # because Pagy's COUNT query can't handle computed ORDER BY columns
            # Use .size on grouped count hash to get total number of groups
            count_result = collection.unscope(:order, :select).distinct.count
            count = count_result.is_a?(Hash) ? count_result.size : count_result
            @pagy, records = pagy(:offset, collection, limit: limit, count: count)
          else
            # Uses countish paginator which is faster as it avoids COUNT queries
            @pagy, records = pagy(:countish, collection, limit: limit)
          end

          records
        end
      end
    end
  end
end
