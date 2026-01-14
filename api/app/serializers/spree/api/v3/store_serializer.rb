module Spree
  module Api
    module V3
      class StoreSerializer < BaseSerializer
        attributes :id, :name, :url, :meta_description, :meta_keywords, :seo_title,
                   :default_currency, :code, :default, :facebook, :twitter,
                   :instagram, :customer_support_email, :default_locale,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :supported_currencies do |store|
          store.supported_currencies_list.map(&:iso_code)
        end

        attribute :supported_locales do |store|
          store.supported_locales_list
        end
      end
    end
  end
end
