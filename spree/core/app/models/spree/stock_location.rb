module Spree
  class StockLocation < Spree.base_class
    has_prefix_id :sloc  # Spree-specific: stock location

    # Categorizes the location. Open string — extensible by setting any value;
    # KINDS lists the built-in options used by the admin UI dropdown.
    KINDS = %w[warehouse store fulfillment_center].freeze

    # Pickup stock policy: 'local' = only items physically at this location are
    # collectable; 'any' = items can be transferred from other locations
    # (ship-to-store). See docs/plans/6.0-fulfillment-and-delivery.md.
    PICKUP_STOCK_POLICIES = %w[local any].freeze

    include Spree::SingleStoreResource
    include Spree::HasExternalReferences
    if defined?(Spree::Security::StockLocations)
      include Spree::Security::StockLocations
    end

    acts_as_paranoid

    has_many :fulfillments, class_name: 'Spree::Fulfillment'
    has_many :shipments, class_name: 'Spree::Fulfillment', foreign_key: :stock_location_id, deprecated: true
    has_many :stock_levels, class_name: 'Spree::StockLevel', dependent: :delete_all, inverse_of: :stock_location
    has_many :variants, through: :stock_levels
    has_many :stock_movements, through: :stock_levels

    has_iso_geography

    # Whose shelf this is. Nil is the operator's own — the only case in a store
    # that is not a marketplace.
    belongs_to :seller, class_name: 'Spree::Seller', optional: true, inverse_of: :stock_locations

    # Name uniqueness is per owner rather than per store (see UniqueName, which
    # this deliberately does not include): an operator and each of their sellers
    # may each have a "Warehouse", which is what a marketplace looks like.
    normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }
    validates :name, presence: true,
                     uniqueness: { case_sensitive: false, allow_blank: true,
                                   scope: [*spree_base_uniqueness_scope, :store_id, :seller_id] }

    validates :kind, presence: true
    validates :pickup_stock_policy, inclusion: { in: PICKUP_STOCK_POLICIES }
    validates :pickup_ready_in_minutes,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 },
              allow_nil: true

    self.whitelisted_ransackable_attributes = %w[
      name active default kind pickup_enabled
      country_code state_code created_at updated_at
      seller_id
    ]
    self.whitelisted_ransackable_associations = %w[seller]

    scope :active, -> { where(active: true) }
    scope :pickup_enabled, -> { where(pickup_enabled: true) }
    scope :order_default, -> { order(default: :desc, name: :asc) }
    # The operator's own locations — a marketplace's first-party stock.
    scope :first_party, -> { where(seller_id: nil) }
    scope :owned_by, ->(store_id:, seller_id:) { where(store_id: store_id, seller_id: seller_id) }

    after_create :create_stock_levels, if: :propagate_all_variants?
    after_save :ensure_one_default
    after_update :conditional_touch_records

    delegate :name, :iso3, :iso_name, to: :country, prefix: true, allow_nil: true

    def state_text
      state_code.presence || state.try(:name) || state_name
    end

    # Wrapper for creating a new stock item respecting the backorderable config
    def propagate_variant(variant)
      stock_levels.create!(variant: variant, backorderable: backorderable_default)
    end

    # Return either an existing stock item or create a new one. Useful in
    # scenarios where the user might not know whether there is already a stock
    # item for a given variant
    def set_up_stock_level(variant)
      stock_level(variant) || propagate_variant(variant)
    end

    # Returns an instance of StockLevel for the variant id.
    #
    # @param variant_id [String] The id of a variant.
    #
    # @return [StockLevel] Corresponding StockLevel for the StockLocation's variant.
    def stock_level(variant_id)
      stock_levels.where(variant_id: variant_id).order(:id).first
    end

    def stocks?(variant)
      stock_levels.exists?(variant: variant)
    end

    # @deprecated Use {#stock_levels}; removed in 6.1.
    def stock_items
      Spree::Deprecation.warn('Spree::StockLocation#stock_items is deprecated and will be removed in Spree 6.1. Use #stock_levels instead.')
      stock_levels
    end

    # @deprecated Use {#stock_level}; removed in 6.1.
    def stock_item(variant_id)
      Spree::Deprecation.warn('Spree::StockLocation#stock_item is deprecated and will be removed in Spree 6.1. Use #stock_level instead.')
      stock_level(variant_id)
    end

    # @deprecated Use {#set_up_stock_level}; removed in 6.1.
    def set_up_stock_item(variant)
      Spree::Deprecation.warn('Spree::StockLocation#set_up_stock_item is deprecated and will be removed in Spree 6.1. Use #set_up_stock_level instead.')
      set_up_stock_level(variant)
    end

    # @deprecated Use {#stock_level_or_create}; removed in 6.1.
    def stock_item_or_create(variant_or_variant_id)
      Spree::Deprecation.warn('Spree::StockLocation#stock_item_or_create is deprecated and will be removed in Spree 6.1. Use #stock_level_or_create instead.')
      stock_level_or_create(variant_or_variant_id)
    end

    # Attempts to look up StockLevel for the variant, and creates one if not found.
    #
    # @param variant Variant instance or Variant ID
    #
    # @return [StockLevel] Corresponding StockLevel for the StockLocation's variant.
    def stock_level_or_create(variant_or_variant_id)
      if variant_or_variant_id.is_a?(Spree::Variant)
        variant_id = variant_or_variant_id.id
        variant = variant_or_variant_id
      else
        variant_id = variant_or_variant_id
        variant = Spree::Variant.find(variant_or_variant_id)
      end
      stock_level(variant_id) || propagate_variant(variant)
    end

    # Returns the count on hand number for the variant
    #
    # @param variant Variant instance
    #
    # @return [Integer]
    def count_on_hand(variant)
      stock_level(variant).try(:count_on_hand)
    end

    def backorderable?(variant)
      stock_level(variant).try(:backorderable?)
    end

    # The five stock verbs are the public surface — extensions call these
    # rather than creating movements themselves, so every row comes out typed
    # and carrying its cause.

    # Goods arrived: a purchase order, a transfer receipt, a return.
    #
    # @param variant [Spree::Variant]
    # @param quantity [Integer]
    # @param cause [ApplicationRecord, nil] the record this is happening for
    # @return [Spree::StockMovement]
    def restock(variant, quantity, cause = nil, persist: true)
      move(variant, quantity, kind: 'received', cause: cause, persist: persist)
    end

    # Goods left.
    #
    # @param force [Boolean] record the departure even if it leaves the shelf
    #   below zero. A merchant forcing a dispatch has decided the parcel left
    #   whatever the ledger claims.
    # @return [Spree::StockMovement]
    def unstock(variant, quantity, cause = nil, persist: true, force: false)
      move(variant, quantity, kind: 'shipped', cause: cause, persist: persist, force: force)
    end

    # Promises stock to a placed order. The cause is the fulfillment, never
    # the order: it owns the origin location and the unit split, and the order
    # comes along with it.
    #
    # @param fulfillment [Spree::Fulfillment]
    # @return [Spree::StockMovement]
    def allocate(variant, quantity, fulfillment)
      move(variant, quantity, kind: 'allocated', cause: fulfillment)
    end

    # Withdraws a promise — a canceled, relocated or shrunk fulfillment.
    # Nothing physical moves.
    #
    # @param fulfillment [Spree::Fulfillment]
    # @return [Spree::StockMovement]
    def release(variant, quantity, fulfillment)
      move(variant, quantity, kind: 'released', cause: fulfillment)
    end

    # A manual correction — an inventory count, shrinkage, damage. Signed, so
    # a negative quantity writes stock off.
    #
    # @param reason [String] audit text, required
    # @return [Spree::StockMovement]
    def adjust(variant, quantity, reason:)
      move(variant, quantity, kind: 'adjusted', reason: reason)
    end

    def move(variant, quantity, kind:, cause: nil, reason: nil, persist: true, force: false)
      stock_level = stock_level_or_create(variant)
      attributes = { quantity: quantity, kind: kind, reason: reason, **cause_attributes(cause) }

      if persist
        stock_level.stock_movements.create!(attributes) { |movement| movement.force = force }
      else
        # StockTransfer builds its movements before it is saved, so they ride
        # along on its own association rather than being created here.
        built = stock_level.stock_movements.build(attributes)
        built.force = force
        cause.stock_movements << built
        built
      end
    end

    def fill_status(variant, quantity)
      if item = stock_level_or_create(variant)
        if item.available_count >= quantity
          on_hand = quantity
          backordered = 0
        else
          on_hand = item.available_count
          on_hand = 0 if on_hand < 0
          # A pre-order oversells like a backorder: the shortfall becomes
          # backordered inventory units (the backorder_limit cap is enforced
          # upstream by Stock::Quantifier#can_supply?).
          backordered = item.backorderable? || variant.preorder? ? (quantity - on_hand) : 0
        end

        [on_hand, backordered]
      else
        [0, 0]
      end
    end

    def address
      Spree::Address.new(
        address1: address1,
        address2: address2,
        company: company,
        city: city,
        state_code: state_code,
        state_name: state_name,
        country_code: country_code,
        zipcode: zipcode,
        phone: phone
      )
    end

    # needed for address form
    def require_name?
      false
    end

    # needed for address form
    def require_company?
      false
    end

    def require_phone?
      false
    end

    def show_company_address_field?
      true
    end

    def display_name
      @display_name ||= [admin_name, name].delete_if(&:blank?).join(' / ')
    end

    private

    # One cause in, the foreign keys it implies out. A fulfillment brings its
    # order with it because "which order was this for?" must not cost a join.
    # The set is closed and core-owned — extensions register causes by adding
    # a branch here, never by inventing a movement column.
    def cause_attributes(cause)
      case cause
      when Spree::Fulfillment   then { fulfillment: cause, order: cause.order }
      when Spree::Return        then { return: cause, order: cause.order }
      when Spree::Exchange      then { exchange: cause, order: cause.order }
      when Spree::StockTransfer then { stock_transfer: cause }
      when Spree::Order         then { order: cause }
      else {}
      end
    end

    def create_stock_levels
      Spree::StockLocations::StockLevels::CreateJob.perform_later(self)
    end

    # One default per OWNER, not per store: on a marketplace the operator has a
    # default and so does every seller, so scoping this to the store would let
    # a seller saving their own default silently demote the operator's.
    def ensure_one_default
      return unless default

      siblings = self.class.owned_by(store_id: store_id, seller_id: seller_id).where.not(id: id)
      siblings.where(default: true).update_all(default: false)
      siblings.update_all(updated_at: Time.current)
    end

    def conditional_touch_records
      return unless active_changed?

      stock_levels.update_all(updated_at: Time.current)
      variants.update_all(updated_at: Time.current)
    end
  end
end
