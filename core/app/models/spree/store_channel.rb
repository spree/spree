module Spree
  class StoreChannel < ApplicationRecord
    belongs_to :store, class_name: 'Spree::Store'
    has_many :orders, class_name: 'Spree::Order', foreign_key: :channel_id

    validates :name, :store, presence: true
    validates :name, uniqueness: { scope: :store_id }
  end
end
