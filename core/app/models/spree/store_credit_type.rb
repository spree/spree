module Spree
  class StoreCreditType < ActiveRecord::Base
    DEFAULT_TYPE_NAME = 'Expiring'
    has_many :store_credits, class_name: 'Spree::StoreCredit', foreign_key: 'type_id'
  end
end
