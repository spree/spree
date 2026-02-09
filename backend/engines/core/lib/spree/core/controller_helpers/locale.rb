module Spree
  module Core
    module ControllerHelpers
      module Locale
        extend ActiveSupport::Concern

        included do
          before_action :set_locale
          before_action :set_fallback_locale

          if defined?(helper_method)
            helper_method :supported_locales
            helper_method :supported_locales_for_all_stores
            helper_method :current_locale
            helper_method :supported_locale?
            helper_method :available_locales
            helper_method :locale_param
          end
        end

        def set_locale
          I18n.default_locale = default_locale unless Spree.always_use_translations?
          I18n.locale = current_locale
        end

        def set_fallback_locale
          return unless respond_to?(:current_store) && current_store.present?

          Spree::Locales::SetFallbackLocaleForStore.new.call(store: current_store)
        end

        def default_locale
          @default_locale ||= current_store&.default_locale || Rails.application.config.i18n.default_locale || I18n.default_locale
        end

        def current_locale
          @current_locale ||= if user_locale?
                                try_spree_current_user.selected_locale
                              elsif params_locale?
                                params[:locale]
                              elsif config_locale?
                                config_locale
                              else
                                default_locale
                              end
        end

        def config_locale?
          respond_to?(:config_locale, true) && config_locale.present?
        end

        def params_locale?
          params[:locale].present? && supported_locale?(params[:locale])
        end

        def user_locale?
          Spree::Config.use_user_locale && try_spree_current_user && supported_locale?(try_spree_current_user.selected_locale)
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

        def find_with_fallback_default_locale(&block)
          result = begin
            block.call
          rescue ActiveRecord::RecordNotFound => _e
            nil
          end

          result || Mobility.with_locale(current_store.default_locale) { block.call }
        end
      end
    end
  end
end
