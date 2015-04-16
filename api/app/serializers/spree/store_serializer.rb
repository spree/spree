module Spree
  class StoreSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.store_attributes
    attributes  :id, :name, :url, :meta_description, :meta_keywords, :seo_title,
                :mail_from_address, :default_currency, :code, :default
  end
end
