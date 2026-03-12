module Spree
  module Api
    module V3
      module Admin
        class StoreSerializer < V3::BaseSerializer
          typelize name: :string, url: :string, code: :string,
                   default_currency: :string, default_locale: :string,
                   supported_currencies: [:string, multi: true],
                   supported_locales: [:string, multi: true],
                   mail_from_address: :string,
                   customer_support_email: [:string, nullable: true],
                   new_order_notifications_email: [:string, nullable: true],
                   description: [:string, nullable: true],
                   address: [:string, nullable: true],
                   contact_phone: [:string, nullable: true],
                   seo_title: [:string, nullable: true],
                   meta_keywords: [:string, nullable: true],
                   meta_description: [:string, nullable: true],
                   default: :boolean,
                   logo_url: [:string, nullable: true],
                   mailer_logo_url: [:string, nullable: true]

          attributes :id, :name, :url, :code,
                     :default_currency, :default_locale,
                     :supported_currencies, :supported_locales,
                     :mail_from_address, :customer_support_email,
                     :new_order_notifications_email,
                     :description, :address, :contact_phone,
                     :seo_title, :meta_keywords, :meta_description,
                     :default,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :logo_url do |store|
            store.logo.attached? ? Rails.application.routes.url_helpers.url_for(store.logo) : nil
          end

          attribute :mailer_logo_url do |store|
            store.mailer_logo.attached? ? Rails.application.routes.url_helpers.url_for(store.mailer_logo) : nil
          end
        end
      end
    end
  end
end
