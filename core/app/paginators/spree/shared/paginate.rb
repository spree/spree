module Spree
  module Shared
    class Paginate
      def initialize(collection, params)
        @collection = collection
        @page       = params[:page]
        @per_page   = params[:per_page]
      end

      def call
        collection.page(page).per(per_page)
      end

      private

      attr_reader :collection, :page, :per_page
    end
  end
end
