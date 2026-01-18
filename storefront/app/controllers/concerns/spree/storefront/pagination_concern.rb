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
          # Uses countish paginator which is faster as it avoids COUNT queries
          @pagy, records = pagy(:countish, collection, limit: limit)
          records
        end
      end
    end
  end
end
