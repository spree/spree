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
        end

        def set_locale
          I18n.locale = current_locale
        end

        def current_locale
          # session support was previously in SpreeI18n so we would like to keep it for now
          # for easer upgrade
          @current_locale ||= if defined?(session) && session.key?(:locale) && supported_locale?(session[:locale])
                                session[:locale]
                              elsif params[:locale].present? && supported_locale?(params[:locale])
                                params[:locale]
                              elsif respond_to?(:config_locale, true) && config_locale.present?
                                config_locale
                              else
                                current_store.default_locale || Rails.application.config.i18n.default_locale || I18n.default_locale
                              end
        end

        def supported_locales
          @supported_locales ||= current_store.supported_locales_list
        end

        def supported_locale?(locale_code)
          supported_locales.include?(locale_code&.to_s)
        end

        def supported_locales_for_all_stores
          @supported_locales_for_all_stores ||= (if defined?(SpreeI18n)
                                                   (SpreeI18n::Locale.all << :en).map(&:to_s)
                                                 else
                                                   [Rails.application.config.i18n.default_locale, I18n.locale, :en]
                                                 end).uniq.compact
        end

        def available_locales
          Spree::Store.available_locales
        end
      end
    end
  end
end
