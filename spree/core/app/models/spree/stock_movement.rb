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

    # `with_deleted` because the ledger outlives what it describes: a level is
    # soft-deleted whenever a product save stops listing its location, and
    # without this the default scope propagates into every join — taking the
    # history of those units out of `for_store` and out of the API with it.
    belongs_to :stock_level, -> { with_deleted }, class_name: 'Spree::StockLevel', inverse_of: :stock_movements
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

    # Whether this write may leave the shelf below zero. An instruction about
    # this one movement rather than a property of it, so it is never
    # persisted — the same shape as {Spree::Fulfillment#notify_customer}.
    attr_accessor :force

    after_create :apply_to_stock_level

    validates :quantity, :kind, presence: true
    validates :kind, inclusion: { in: KINDS }, allow_blank: true
    validates :quantity, numericality: {
      other_than: 0,
      greater_than_or_equal_to: QUANTITY_LIMITS[:min],
      less_than_or_equal_to: QUANTITY_LIMITS[:max],
      only_integer: true
    }, allow_nil: true
    # The three order-driven kinds carry their direction in the kind, so they
    # are written positive and read through `abs`. Accepting a negative would
    # store a row whose sign contradicts the change it caused — the ledger
    # would say one thing and the shelf another.
    validates :quantity, numericality: { greater_than: 0 }, allow_nil: true,
                         if: -> { allocated? || released? || shipped? }
    validates :reason, presence: true, if: :adjusted?

    scope :recent, -> { order(created_at: :desc) }
    KINDS.each do |movement_kind|
      scope movement_kind, -> { where(kind: movement_kind) }
      define_method("#{movement_kind}?") { kind == movement_kind }
    end

    # Movements for products assigned to `store`, walking
    # `stock level → variant → product → store`. The table carries no store of
    # its own, so this walk is the only tenancy path there is.
    scope :for_store, ->(store) {
      joins(stock_level: { variant: :product }).where(spree_products: { store_id: store.id })
    }

    delegate :variant, :variant_id, to: :stock_level, allow_nil: true
    delegate :product, to: :variant

    # `stock_item_id` rides along for one release beside the name that replaced
    # it: Ransack resolves attribute aliases, and dropping the old filter would
    # hand a client still sending it the whole collection rather than an error.
    self.whitelisted_ransackable_attributes = %w[quantity kind reason created_at stock_level_id
                                                 stock_item_id order_id fulfillment_id return_id
                                                 exchange_id stock_transfer_id]
    self.whitelisted_ransackable_associations = %w[stock_level]

    # Stored audit text for a correction nobody labelled. Deliberately
    # resolved in English: the column is read by every admin afterwards, not
    # only by whoever happened to type the correction.
    #
    # @return [String]
    def self.default_adjustment_reason
      Spree.t('stock_movement.reasons.manual_adjustment', locale: :en)
    end

    # A movement is an immutable audit row: once written, nothing may rewrite
    # it. The guard is against an *update*, so it reads `persisted?` at the
    # moment the save begins rather than afterwards — a parent's autosave can
    # insert this row while its own save is still in flight (the stock level
    # holds it through `inverse_of`), which leaves it persisted mid-insert. That
    # row is being created, not updated, so it must still be allowed to finish.
    def readonly?
      persisted? && !being_created?
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

    # Re-entrant: a parent's autosave can call this again from inside the outer
    # save, and the inner call must not clear the outer one's guard.
    def create_or_update(...)
      @create_depth = @create_depth.to_i + 1
      @being_created = true if new_record?
      super
    ensure
      @create_depth -= 1
      @being_created = false if @create_depth.zero?
    end

    def being_created?
      @being_created.present?
    end

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

    # The shelf may only be driven below zero when the caller said so: a
    # merchant forcing a dispatch has decided the parcel left whatever the
    # ledger claims. Nothing else — a transfer least of all — may send goods a
    # warehouse does not have.
    #
    # Retiring the promise keys off the cause instead, because only a dispatch
    # has one to retire: consuming an allocation on a transfer would take a
    # different order's units.
    def apply_departure
      stock_level.adjust_count_on_hand(-quantity.abs, force: force.present?)
      stock_level.release_allocated_count(quantity.abs) if fulfillment_id.present?
    end
  end
end
