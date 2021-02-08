module Spree
  module Shared
    class Paginate
      def initialize(collection, params)
        @collection = collection
        @page       = params[:page]

        default_pages = Spree::Api::Config[:api_v2_per_page_limit]

        if params[:per_page].to_i.between?(1, default_pages)
          @per_page = params[:per_page]
        else
          @per_page = default_pages.to_i
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
