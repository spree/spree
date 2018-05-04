module Spree
  module Admin
    class GeneralSettingsController < Spree::Admin::BaseController
      include Spree::Backend::Callbacks

      def edit
        @preferences_security = []
      end

      def update
        params.each do |name, value|
          next unless Spree::Config.has_preference? name
          Spree::Config[name] = value
        end

        flash[:success] = Spree.t(:successfully_updated, resource: Spree.t(:general_settings))
        redirect_to edit_admin_general_settings_path
      end

      def clear_cache
        Rails.cache.clear
        invoke_callbacks(:clear_cache, :after)
        head :no_content
      end
    end
  end
end
