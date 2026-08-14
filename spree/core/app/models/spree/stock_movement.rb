module Spree
  class StockMovement < Spree.base_class
    has_prefix_id :sm

    # What happened to stock. The kind carries the direction, so the three
    # order-driven kinds are written positive; `received` and `adjusted` keep
    # the signed meaning of quantity.
    KINDS = %w[received allocated shipped released adjusted].freeze

    QUANTITY_LIMITS = {
      max: 2**31 - 1,
      min: -2**31
    }.freeze

    include Spree::StockMovement::CustomEvents

    publishes_lifecycle_events

    belongs_to :stock_level, class_name: 'Spree::StockLevel', inverse_of: :stock_movements
    # @deprecated Replaced by the concrete cause keys below; dropped in 6.1.
    belongs_to :originator, polymorphic: true, optional: true

    # The cause. A fulfillment-driven row carries its order too, so "which
    # order was this for?" costs no join.
    belongs_to :order, class_name: 'Spree::Order', optional: true
    belongs_to :fulfillment, class_name: 'Spree::Fulfillment', optional: true
    belongs_to :return, class_name: 'Spree::Return', optional: true
    belongs_to :exchange, class_name: 'Spree::Exchange', optional: true
    belongs_to :stock_transfer, class_name: 'Spree::StockTransfer', optional: true

    alias_attribute :stock_item_id, :stock_level_id

    after_create :apply_to_stock_level

    validates :stock_level, :quantity, :kind, presence: true
    validates :kind, inclusion: { in: KINDS }, allow_blank: true
    validates :quantity, numericality: {
      other_than: 0,
      greater_than_or_equal_to: QUANTITY_LIMITS[:min],
      less_than_or_equal_to: QUANTITY_LIMITS[:max],
      only_integer: true
    }, allow_nil: true
    validates :reason, presence: true, if: :adjusted?

    scope :recent, -> { order(created_at: :desc) }

    # Movements for products assigned to `store`, walking
    # `stock level → variant → product → store`. The table carries no store of
    # its own, so this walk is the only tenancy path there is.
    scope :for_store, ->(store) {
      joins(stock_level: { variant: :product }).where(spree_products: { store_id: store.id })
    }
    KINDS.each do |movement_kind|
      scope movement_kind, -> { where(kind: movement_kind) }
      define_method("#{movement_kind}?") { kind == movement_kind }
    end

    delegate :variant, :variant_id, to: :stock_level, allow_nil: true
    delegate :product, to: :variant

    self.whitelisted_ransackable_attributes = %w[quantity kind reason created_at stock_level_id
                                                 order_id fulfillment_id return_id exchange_id
                                                 stock_transfer_id]
    self.whitelisted_ransackable_associations = %w[stock_level]

    # Stored audit text for a correction nobody labelled. Deliberately
    # resolved in English: the column is read by every admin afterwards, not
    # only by whoever happened to type the correction.
    #
    # @return [String]
    def self.default_adjustment_reason
      Spree.t('stock_movement.reasons.manual_adjustment', locale: :en)
    end

    def readonly?
      persisted?
    end

    # @deprecated Use {#stock_level}; removed in 6.1.
    def stock_item
      Spree::Deprecation.warn('Spree::StockMovement#stock_item is deprecated and will be removed in Spree 6.1. Use #stock_level instead.')
      stock_level
    end

    # @deprecated Use {#stock_level=}; removed in 6.1.
    def stock_item=(record)
      Spree::Deprecation.warn('Spree::StockMovement#stock_item= is deprecated and will be removed in Spree 6.1. Use #stock_level= instead.')
      self.stock_level = record
    end

    private

    # The single place count_on_hand and allocated_count change.
    #
    # A correction applies even to a variant that stopped tracking inventory —
    # that is how turning tracking off writes its stock away, and a correction
    # is a deliberate statement about the shelf either way.
    def apply_to_stock_level
      return unless adjusted? || stock_level.should_track_inventory?

      case kind
      when 'received', 'adjusted' then stock_level.adjust_count_on_hand(quantity)
      when 'allocated'            then stock_level.adjust_allocated_count(quantity.abs)
      when 'released'             then stock_level.release_allocated_count(quantity.abs)
      when 'shipped'              then apply_departure
      end
    end

    # Departure is a physical fact, so it is allowed to leave the shelf
    # negative — see the plan's "shipping from an empty shelf". The stock
    # level needs to know that to relax its own non-negative guard.
    def apply_departure
      stock_level.applying_movement_kind = 'shipped'
      stock_level.adjust_count_on_hand(-quantity.abs)
      stock_level.release_allocated_count(quantity.abs)
    ensure
      stock_level.applying_movement_kind = nil
    end
  end
end
