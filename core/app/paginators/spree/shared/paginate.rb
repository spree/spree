module Spree
  module Shared
    class Paginate
      def initialize(collection, params)
        @collection = collection
        @page       = params[:page]

        per_page_limit = Spree::Api::Config[:api_v2_per_page_limit]

        @per_page = if params[:per_page].to_i.between?(1, per_page_limit)
                      params[:per_page]
                    else
                      Kaminari.config.default_per_page
                    end
      end

      def call
        collection.page(page).per(per_page)
      end

      private

      attr_reader :collection, :page, :per_page
    end
  end
end
