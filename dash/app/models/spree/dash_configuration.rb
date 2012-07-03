module Spree
  class DashConfiguration < Preferences::Configuration
    preference :app_id, :string
    preference :app_token, :string
    preference :site_id, :string
    preference :token, :string
    preference :locale, :string, :default => 'en_US'

    def configured?
      preferred_app_id.present? and preferred_site_id.present? and preferred_token.present?
    end
  end
end
