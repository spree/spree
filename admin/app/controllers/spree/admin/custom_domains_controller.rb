module Spree
  module Admin
    class CustomDomainsController < ResourceController
      add_breadcrumb Spree.t(:domains), :admin_custom_domains_path

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

      def permitted_resource_params
        params.require(:custom_domain).permit(Spree::PermittedAttributes.custom_domain_attributes)
      end
    end
  end
end
