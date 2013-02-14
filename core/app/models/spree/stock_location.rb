module Spree
  class StockLocation < ActiveRecord::Base
<<<<<<< HEAD
    has_many :stock_items, dependent: :destroy
    has_many :stock_movements, through: :stock_items

    belongs_to :state
    belongs_to :country

    validates_presence_of :name

    attr_accessible :name, :active, :address1, :address2, :city, :zipcode,
                    :state_name, :state_id, :country_id, :phone

    scope :active, -> { where(active: true) }

    after_create :create_stock_items

    def stock_item(variant)
      stock_items.where(variant_id: variant).first
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

    def unstock(variant, quantity, originator = nil)
      move(variant, -quantity, originator)
    end

    def move(variant, quantity, originator = nil)
      stock_item(variant).stock_movements.create!(quantity: quantity, originator: originator)
    end

    def fill_status(variant, quantity)
      item = stock_item(variant)

      if item.count_on_hand >= quantity
        on_hand = quantity
        backordered = 0
      else
        on_hand = item.count_on_hand
        on_hand = 0 if on_hand < 0
        backordered = item.backorderable? ? (quantity - on_hand) : 0
      end

      [on_hand, backordered]
    end

    private

      def create_stock_items
        Spree::Variant.all.each do |v|
          self.stock_items.create!(variant: v)
        end
      end
=======
    belongs_to :address
    attr_accessible :name
    has_many :stock_items, :dependent => :destroy

    validates_presence_of :name

    def packages(order)
      packages = [default_package(order)]
      splitter(order).split(packages)
    end

    def default_package(order)
      package = StockPackage.new(self)
      order.line_items.each do |line_item|
        on_hand, backordered = stock_status(line_item.variant, line_item.quantity)
        package.add line_item.variant, on_hand, :on_hand if on_hand > 0
        package.add line_item.variant, backordered, :backordered if backordered > 0
      end
      package
    end

    def splitter(order)
      # TODO build a chain of splitters
      StockSplitter::Base.new(self, order)
    end

    private
    def stock_item_for_variant(variant)
      stock_items.where(variant: variant).first
    end

    def stock_status(variant, quantity)
      on_hand = count_on_hand(variant)
      #TODO fancy math for backorder counts
      [on_hand, 0]
    end

    def count_on_hand(variant)
      stock_item = stock_items.where(variant_id: variant).first
      stock_item.try(:count_on_hand)
    end
>>>>>>> stock locations and items
  end
end
