module Spree
  module Seeds
    class Stores
      prepend Spree::ServiceModule::Base

      def call
        default_store = Spree::Store.default

        if default_store.persisted?
          default_store.update!(default_country: Spree::Country.find_by(iso: 'US') || Spree::Country.first)
        else
          Spree::Store.new do |s|
            s.name                         = 'Shop'
            s.code                         = 'shop'
            s.url                          = Rails.application.routes.default_url_options[:host] || 'localhost:3000'
            s.mail_from_address            = 'no-reply@example.com'
            s.customer_support_email       = 'support@example.com'
            s.default_currency             = 'USD'
            s.default_country              = Spree::Country.find_by(iso: 'US') || Spree::Country.first
            s.default_locale               = I18n.locale
          end.save!
        end
      end
    end
  end
end
