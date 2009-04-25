# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class LocalizationExtension < Spree::Extension
  version "0.1.1"
  description "Localization support for Spree"
  url "http://support.spreecommerce.com/wiki/1/I18n"

  def activate
    ApplicationController.class_eval do
        before_filter :set_user_language
        
        private
        def set_user_language
          locale = session[:locale] || Spree::Config[:default_locale] || I18n.default_locale
          locale = AVAILABLE_LOCALES.keys.include?(locale) ? locale : I18n.default_locale
          I18n.locale = locale
        end
    end
  end
end
