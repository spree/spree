module Spree
  class StoreCreditType < Spree.base_class
    DEFAULT_TYPE_NAME = 'Expiring'.freeze
    has_many :store_credits, class_name: 'Spree::StoreCredit', foreign_key: 'type_id'

    validates :name, presence: true
  end
end
