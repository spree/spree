module Spree
  class StoreCreditType < Spree::Base
    DEFAULT_TYPE_NAME = 'Expiring'.freeze
    has_many :store_credits, class_name: 'Spree::StoreCredit', foreign_key: 'type_id'
  end
end
