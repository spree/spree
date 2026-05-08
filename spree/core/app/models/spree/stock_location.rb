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

    include Spree::UniqueName
    if defined?(Spree::Security::StockLocations)
      include Spree::Security::StockLocations
    end
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end

    acts_as_paranoid

    has_many :shipments
    has_many :stock_items, dependent: :delete_all, inverse_of: :stock_location
    has_many :variants, through: :stock_items
    has_many :stock_movements, through: :stock_items

    belongs_to :state, class_name: 'Spree::State', optional: true
    belongs_to :country, class_name: 'Spree::Country'

    validates :kind, presence: true
    validates :pickup_stock_policy, inclusion: { in: PICKUP_STOCK_POLICIES }
    validates :pickup_ready_in_minutes,
              numericality: { only_integer: true, greater_than_or_equal_to: 0 },
              allow_nil: true

    self.whitelisted_ransackable_attributes = %w[
      name active default kind pickup_enabled
      country_id state_id created_at updated_at
    ]

    scope :active, -> { where(active: true) }
    scope :pickup_enabled, -> { where(pickup_enabled: true) }
    scope :order_default, -> { order(default: :desc, name: :asc) }

    before_validation :normalize_country
    before_validation :normalize_state

    after_create :create_stock_items, if: :propagate_all_variants?
    after_save :ensure_one_default
    after_update :conditional_touch_records

    delegate :name, :iso3, :iso, :iso_name, to: :country, prefix: true, allow_nil: true
    delegate :abbr, to: :state, prefix: true, allow_nil: true

    # Writer methods for API convenience — accept ISO/abbr codes instead of FK IDs.
    # Mirrors Spree::Address: SDK clients use country_iso/state_abbr because
    # Country/State don't expose prefixed IDs (their `iso` is the public handle).
    def country_iso=(value)
      @country_iso_input = value
    end

    def state_abbr=(value)
      @state_abbr_input = value
    end

    def state_text
      state.try(:abbr) || state.try(:name) || state_name
    end

    # Wrapper for creating a new stock item respecting the backorderable config
    def propagate_variant(variant)
      stock_items.create!(variant: variant, backorderable: backorderable_default)
    end

    # Return either an existing stock item or create a new one. Useful in
    # scenarios where the user might not know whether there is already a stock
    # item for a given variant
    def set_up_stock_item(variant)
      stock_item(variant) || propagate_variant(variant)
    end

    # Returns an instance of StockItem for the variant id.
    #
    # @param variant_id [String] The id of a variant.
    #
    # @return [StockItem] Corresponding StockItem for the StockLocation's variant.
    def stock_item(variant_id)
      stock_items.where(variant_id: variant_id).order(:id).first
    end

    def stocks?(variant)
      stock_items.exists?(variant: variant)
    end

    # Attempts to look up StockItem for the variant, and creates one if not found.
    #
    # @param variant Variant instance or Variant ID
    #
    # @return [StockItem] Corresponding StockItem for the StockLocation's variant.
    def stock_item_or_create(variant_or_variant_id)
      if variant_or_variant_id.is_a?(Spree::Variant)
        variant_id = variant_or_variant_id.id
        variant = variant_or_variant_id
      else
        variant_id = variant_or_variant_id
        variant = Spree::Variant.find(variant_or_variant_id)
      end
      stock_item(variant_id) || propagate_variant(variant)
    end

    # Returns the count on hand number for the variant
    #
    # @param variant Variant instance
    #
    # @return [Integer]
    def count_on_hand(variant)
      stock_item(variant).try(:count_on_hand)
    end

    def backorderable?(variant)
      stock_item(variant).try(:backorderable?)
    end

    def restock(variant, quantity, originator = nil, persist: true)
      move(variant, quantity, originator, persist: persist)
    end

    def restock_backordered(variant, quantity, _originator = nil)
      item = stock_item_or_create(variant)
      item.update_columns(
        count_on_hand: item.count_on_hand + quantity,
        updated_at: Time.current
      )
    end

    def unstock(variant, quantity, originator = nil, persist: true)
      move(variant, -quantity, originator, persist: persist)
    end

    def move(variant, quantity, originator = nil, persist: true)
      stock_item = stock_item_or_create(variant)

      if persist
        stock_item.stock_movements.create!(quantity: quantity, originator: originator)
      else
        originator.stock_movements << stock_item.stock_movements.build(quantity: quantity)
      end
    end

    def fill_status(variant, quantity)
      if item = stock_item_or_create(variant)
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

    def address
      Spree::Address.new(
        address1: address1,
        address2: address2,
        company: company,
        city: city,
        state: state,
        state_name: state_name,
        country: country,
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

    def normalize_country
      iso = @country_iso_input
      return if iso.blank?

      self.country = Spree::Country.by_iso(iso)
      @country_iso_input = nil
    end

    def normalize_state
      abbr = @state_abbr_input
      return if abbr.blank? || country.blank?

      self.state = country.states.find_by(abbr: abbr)
      @state_abbr_input = nil
    end

    def create_stock_items
      Spree::StockLocations::StockItems::CreateJob.perform_later(self)
    end

    def ensure_one_default
      if default
        StockLocation.where(default: true).where.not(id: id).update_all(default: false)
        StockLocation.where.not(id: id).update_all(updated_at: Time.current)
      end
    end

    def conditional_touch_records
      return unless active_changed?

      stock_items.update_all(updated_at: Time.current)
      variants.update_all(updated_at: Time.current)
    end
  end
end
