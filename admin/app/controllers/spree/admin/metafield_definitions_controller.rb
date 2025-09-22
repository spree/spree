module Spree
  module Admin
    class MetafieldDefinitionsController < ResourceController
      private

      def location_after_save
        collection_url
      end
    end
  end
end
