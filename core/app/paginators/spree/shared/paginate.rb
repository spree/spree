module Spree
  module Shared
    class Paginate
      def initialize(collection, params)
        @collection = collection
        @page       = params[:page] || 1

        per_page_limit = Spree::Api::Config[:api_v2_per_page_limit]

        @per_page = if params[:per_page].to_i.between?(1, per_page_limit)
                      params[:per_page]
                    else
                      20
                    end
      end

      def call
        # Pagy.new creates a pagy object with pagination metadata
        pagy_obj = Pagy.new(count: collection.count(:all), page: page, items: per_page)

        # Apply offset and limit to the collection
        paginated_collection = collection.offset(pagy_obj.offset).limit(pagy_obj.limit)

        # Attach pagy object to the collection for metadata access
        paginated_collection.define_singleton_method(:pagy) { pagy_obj }

        paginated_collection
      end

      private

      attr_reader :collection, :page, :per_page
    end
  end
end
