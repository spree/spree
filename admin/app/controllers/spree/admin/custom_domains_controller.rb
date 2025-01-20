module Spree
  module Admin
    class CustomDomainsController < ResourceController
      protected

      def collection_url
        spree.admin_custom_domains_path
      end

      def create_turbo_stream_enabled?
        helpers.entri_enabled?
      end

      def location_after_save
        spree.admin_custom_domains_path
      end
    end
  end
end
