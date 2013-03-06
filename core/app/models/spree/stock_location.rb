module Spree
  class StockLocation < ActiveRecord::Base
    has_many :stock_items, dependent: :destroy
    has_many :stock_movements, through: :stock_items

    belongs_to :state
    belongs_to :country

    validates_presence_of :name

    attr_accessible :name, :active, :address1, :address2, :city, :zipcode,
                    :state_name, :state_id, :country_id, :phone

    scope :active, where(active: true)

    def stock_item(variant)
      stock_items.where(variant_id: variant).first
    end

    def count_on_hand(variant)
      stock_item(variant).try(:count_on_hand)
    end
  end
end
