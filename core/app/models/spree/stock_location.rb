module Spree
  class StockLocation < Spree::Base
    has_many :shipments
    has_many :stock_items, dependent: :delete_all, inverse_of: :stock_location
    has_many :stock_movements, through: :stock_items

    belongs_to :state, class_name: 'Spree::State'
    belongs_to :country, class_name: 'Spree::Country'

    validates :name, presence: true

    scope :active, -> { where(active: true) }
    scope :order_default, -> { order(default: :desc, name: :asc) }

    after_create :create_stock_items, if: :propagate_all_variants?
    after_save :ensure_one_default

    def state_text
      state.try(:abbr) || state.try(:name) || state_name
    end

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

    # Returns an instance of StockItem for the variant id.
    #
    # @param variant_id [String] The id of a variant.
    #
    # @return [StockItem] Corresponding StockItem for the StockLocation's variant.
    def stock_item(variant_id)
      stock_items.where(variant_id: variant_id).order(:id).first
    end

    # Attempts to look up StockItem for the variant, and creates one if not found.
    # This method accepts an instance of the variant.
    # Other methods in this model attempt to pass a variant,
    # but controller actions can pass just the variant id as a parameter.
    #
    # @param variant [Variant] Variant instance.
    #
    # @return [StockItem] Corresponding StockItem for the StockLocation's variant.
    def stock_item_or_create(variant)
      stock_item(variant) || stock_items.create(variant_id: variant.id)
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
        updated_at: Time.current
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
        Variant.includes(:product).find_each do |variant|
          propagate_variant(variant)
        end
      end

      def ensure_one_default
        if self.default
          StockLocation.where(default: true).where.not(id: self.id).update_all(default: false)
        end
      end
  end
end
