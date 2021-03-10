module Spree
  module Core
    module ControllerHelpers
      module Locale
        extend ActiveSupport::Concern

        included do
          before_action :set_locale

          helper_method :supported_locales
          helper_method :supported_locales_for_all_stores
          helper_method :current_locale
          helper_method :supported_locale?
          helper_method :available_locales
          helper_method :locale_param
        end

        def set_locale
          I18n.locale = current_locale
        end

        def current_locale
          @current_locale ||= if params[:locale].present? && supported_locale?(params[:locale])
                                params[:locale]
                              elsif respond_to?(:config_locale, true) && config_locale.present?
                                config_locale
                              else
                                current_store&.default_locale || Rails.application.config.i18n.default_locale || I18n.default_locale
                              end
        end

        def supported_locales
          @supported_locales ||= current_store&.supported_locales_list
        end

        def supported_locale?(locale_code)
          return false if supported_locales.nil?

          supported_locales.include?(locale_code&.to_s)
        end

        def supported_locales_for_all_stores
          @supported_locales_for_all_stores ||= Spree.available_locales
        end

        def available_locales
          Spree::Store.available_locales
        end

        def locale_param
          return if I18n.locale.to_s == current_store.default_locale || current_store.default_locale.nil?

          I18n.locale.to_s
        end
      end
    end
  end
end
