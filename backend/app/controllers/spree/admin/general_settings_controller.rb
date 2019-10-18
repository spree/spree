module Spree
  module Admin
    class GeneralSettingsController < Spree::Admin::BaseController
      include Spree::Backend::Callbacks

      before_action :update_currency_settings, only: :update

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

      def render(*args)
        @preferences_currency |= [:allow_currency_change, :show_currency_selector]
        super
      end

      private

      def update_currency_settings
        params.each do |name, value|
          next unless Spree::Config.has_preference?(name) && name.eql?('supported_currencies')

          value = update_value(value)
          Spree::Config[name] = value
        end
      end

      def update_value(value)
        value.split(',').
          map { |curr| ::Money::Currency.find(curr.strip).try(:iso_code) }.
          concat([Spree::Config[:currency]]).
          uniq.
          compact.
          join(',')
      end
    end
  end
end
