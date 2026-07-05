# frozen_string_literal: true

module Spree
  module Admin
    class AllowedOriginsController < ResourceController
      include Spree::Admin::SettingsConcern
      include Spree::Admin::TableConcern

      private

      def model_class
        Spree::AllowedOrigin
      end

      def scope
        current_store.allowed_origins
      end

      def object_name
        'allowed_origin'
      end

      def permitted_resource_params
        params.require(:allowed_origin).permit(permitted_allowed_origin_attributes)
      end

      def location_after_save
        spree.admin_allowed_origins_path
      end

      def location_after_destroy
        spree.admin_allowed_origins_path
      end
    end
  end
end
