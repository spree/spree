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

    after_create :populate_stock_items

    def stock_item(variant)
      stock_items.where(variant_id: variant).first
    end

    def count_on_hand(variant)
      stock_item(variant).try(:count_on_hand)
    end

    def find_or_create_stock_item_for_variant(variant)
      variant_stock_item = stock_item(variant)
      variant_stock_item.present? ? variant_stock_item : stock_items.create!
    end

    def populate_stock_items
      Spree::Variant.all.each do |v|
          self.stock_items.create!(:variant => v)
      end
    end
  end
end
