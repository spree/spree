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
            # Use offset paginator with count_over for GROUP BY/HAVING queries
            # count_over uses COUNT(*) OVER () which works with grouped collections
            @pagy, records = pagy(:offset, collection, limit: limit, count_over: true)
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
