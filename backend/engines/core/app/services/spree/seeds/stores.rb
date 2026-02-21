module Spree
  module Seeds
    class Stores
      prepend Spree::ServiceModule::Base

      def call
        default_store = Spree::Store.default

        unless default_store.persisted?
          Spree::Store.new do |s|
            s.name                         = 'Shop'
            s.code                         = 'shop'
            s.url                          = Rails.application.routes.default_url_options[:host] || 'localhost:3000'
            s.mail_from_address            = 'no-reply@example.com'
            s.customer_support_email       = 'support@example.com'
            s.default_currency             = 'USD'
            s.default_country_iso          = 'US'
            s.default_locale               = I18n.locale
          end.save!
        end
      end
    end
  end
end
