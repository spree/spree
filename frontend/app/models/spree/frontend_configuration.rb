module Spree
  class FrontendConfiguration < Preferences::Configuration
    preference :locale, :string, :default => Rails.application.config.i18n.default_locale
  end
end
