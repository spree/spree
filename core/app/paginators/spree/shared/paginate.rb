module Spree
  module Shared
    class Paginate
      def initialize(collection, params)
        @collection = collection
        @page       = params[:page]

        default_pages = Spree::Api::Config[:api_v2_per_page_limit]

        @per_page = if params[:per_page].to_i.between?(1, default_pages)
                      params[:per_page]
                    elsif params[:per_page].nil?
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
