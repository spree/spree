module Spree
  class StockLocation < ActiveRecord::Base
    has_many :stock_items, dependent: :delete_all
    has_many :stock_movements, through: :stock_items

    belongs_to :state, class_name: 'Spree::State'
    belongs_to :country, class_name: 'Spree::Country'

    validates_presence_of :name

    scope :active, -> { where(active: true) }

    after_create :create_stock_items, :if => "self.propagate_all_variants?"

    # Wrapper for creating a new stock item respecting the backorderable config
    def propagate_variant(variant)
      self.stock_items.create!(variant: variant, backorderable: self.backorderable_default)
    end

    # Return either an existing stock item or create a new one. Useful in
    # scenarios where the user might not know whether there is already a stock
    # item for a given variant
    def set_up_stock_item(variant)
      self.stock_item(variant) || propagate_variant(variant)
    end

    def stock_item(variant)
      stock_items.where(variant_id: variant).order(:id).first
    end

    def stock_item_or_create(variant)
      stock_item(variant) || stock_items.create(variant: variant)
    end

    def count_on_hand(variant)
      stock_item(variant).try(:count_on_hand)
    end

    def backorderable?(variant)
      stock_item(variant).try(:backorderable?)
    end

    def restock(variant, quantity, originator = nil)
      move(variant, quantity, originator)
    end

    def restock_backordered(variant, quantity, originator = nil)
      item = stock_item_or_create(variant)
      item.update_columns(
        count_on_hand: item.count_on_hand + quantity,
        updated_at: Time.now
      )
    end

    def unstock(variant, quantity, originator = nil)
      move(variant, -quantity, originator)
    end

    def move(variant, quantity, originator = nil)
      stock_item_or_create(variant).stock_movements.create!(quantity: quantity,
                                                            originator: originator)
    end

    def fill_status(variant, quantity)
      if item = stock_item(variant)

        if item.count_on_hand >= quantity
          on_hand = quantity
          backordered = 0
        else
          on_hand = item.count_on_hand
          on_hand = 0 if on_hand < 0
          backordered = item.backorderable? ? (quantity - on_hand) : 0
        end

        [on_hand, backordered]
      else
        [0, 0]
      end
    end

    private
      def create_stock_items
        Variant.find_each { |variant| self.propagate_variant(variant) }
      end
  end
end
