module Spree
  module Shared
    class Paginate
      def initialize(collection, params)
        Spree::Deprecation.warn('Spree::Shared::Paginate is deprecated and will be removed in Spree 5.5. Please use Kaminari instead.')

        raise 'Kaminari is not installed. Please add it to your Gemfile.' unless defined?(Kaminari)

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
