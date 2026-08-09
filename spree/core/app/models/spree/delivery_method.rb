module Spree
  class DeliveryMethod < Spree.base_class
    has_prefix_id :dm

    acts_as_paranoid
    include Spree::SingleStoreResource
    include Spree::CalculatedAdjustments
    include Spree::HasCustomFields
    include Spree::Metadata
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end
    include Spree::MemoizedData
    include Spree::TypedAssociations

    extend Spree::DisplayMoney

    MEMOIZED_METHODS = %w[display_estimated_price]

    # Audience a rate refresh is quoting for: the storefront sees only
    # customer-facing methods, the backoffice sees every method.
    STOREFRONT = :storefront
    BACKOFFICE = :backoffice

    # @deprecated Use {STOREFRONT}/{BACKOFFICE}; removed in 6.1.
    DISPLAY_ON_FRONT_END = 1
    # @deprecated Use {STOREFRONT}/{BACKOFFICE}; removed in 6.1.
    DISPLAY_ON_BACK_END = 2

    default_scope { where(deleted_at: nil) }

    has_many :delivery_rates, class_name: 'Spree::DeliveryRate', inverse_of: :delivery_method
    has_many :fulfillments, through: :delivery_rates, class_name: 'Spree::Fulfillment'

    has_many :delivery_method_stock_locations, class_name: 'Spree::DeliveryMethodStockLocation',
             dependent: :destroy, inverse_of: :delivery_method
    has_many :delivery_method_rules, class_name: 'Spree::DeliveryMethodRule',
             dependent: :destroy, inverse_of: :delivery_method
    has_many :pickup_locations, through: :delivery_method_stock_locations, source: :stock_location

    has_many :delivery_method_zones, class_name: 'Spree::DeliveryMethodZone',
                                     foreign_key: 'delivery_method_id'
    has_many :delivery_zones, through: :delivery_method_zones, class_name: 'Spree::DeliveryZone'

    belongs_to :tax_category, -> { with_deleted }, class_name: 'Spree::TaxCategory', optional: true

    attribute :storefront_visible, :boolean, default: true
    attribute :fulfillment_type, :string, default: 'shipping'

    # Every method rates through a calculator; pickup/digital methods default
    # to free so API/dashboard creation doesn't have to send one.
    before_validation :ensure_calculator, on: :create
    after_save :apply_pending_rules, if: :pending_rules?
    attribute :fulfillment_provider, :string, default: 'Spree::FulfillmentProvider::Manual'

    scope :by_fulfillment_type, ->(type) { where(fulfillment_type: type) }

    # Customer-facing methods vs backoffice-only ones (manual courier entry,
    # internal freight). The backoffice always sees every method.
    scope :storefront_visible, -> { where(storefront_visible: true) }
    scope :admin_only, -> { where(storefront_visible: false) }

    # Legacy association names — removed in 6.1.
    has_many :shipping_rates, class_name: 'Spree::DeliveryRate', foreign_key: :delivery_method_id, deprecated: true
    has_many :shipments, through: :delivery_rates, source: :fulfillment, deprecated: true
    has_many :zones, through: :delivery_method_zones, source: :delivery_zone, deprecated: true

    # ShippingCategory eligibility is superseded by fulfillment types
    # (ProductType#fulfillment_types); both tables drop in 6.1.
    has_many :shipping_method_categories, foreign_key: :shipping_method_id, dependent: :destroy, deprecated: true
    has_many :shipping_categories, through: :shipping_method_categories, deprecated: true

    # Real column, so no ransacker is needed — only the allowlist entry the
    # Spree::DisplayOn concern used to contribute.
    self.whitelisted_ransackable_attributes = %w[storefront_visible fulfillment_type]

    validates :name, :fulfillment_type, presence: true
    validates :storefront_visible, inclusion: { in: [true, false] }
    # Strict vocabulary: an unregistered type silently matches no product
    # (empty intersection — no error, just missing rates), so typos must
    # fail loudly. Validated on change only: rows migrated with tokens not
    # yet registered in an initializer stay loadable and savable.
    validates :fulfillment_type,
              inclusion: { in: -> (_record) { Spree.fulfillment_types } },
              if: :fulfillment_type_changed?
    validates :estimated_transit_business_days_min, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
    validates :estimated_transit_business_days_max, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true

    scope :digital, -> { by_fulfillment_type('digital') }

    scope :search_by_name, ->(query) { where(arel_table[:name].lower.matches("%#{query}%")) }

    def include?(address)
      return true unless requires_zone_check?
      return false unless address
      return true if delivery_zones.empty?

      delivery_zones.includes(:members).any? do |zone|
        zone.include?(address)
      end
    end

    # Zones describe the customer's destination address, so only methods
    # that deliver to one are zone-checked.
    def requires_zone_check?
      requires_address?
    end

    def build_tracking_url(tracking)
      return if tracking.blank?

      tracking = tracking.upcase

      # build tracking url automatically
      if tracking_url.blank?
        # use tracking number gem to build tracking url
        # we need to upcase the tracking number
        # https://github.com/jkeen/tracking_number/pull/85
        tracking_number_service(tracking).tracking_url if tracking_number_service(tracking).valid?
      else
        # build tracking url manually
        tracking_url.gsub(/:tracking/, ERB::Util.url_encode(tracking)) # :url_encode exists in 1.8.7 through 2.1.0
      end
    end

    # your shipping method subclasses can override this method to provide a custom tracking number service
    def tracking_number_service(tracking)
      @tracking_number_service ||= Spree.tracking_number_service.new(tracking)
    end

    def pickup?
      fulfillment_type == 'pickup'
    end

    def ensure_calculator
      self.calculator ||= Spree::Calculator::Shipping::FlatRate.new(preferred_amount: 0)
    end

    def pickup_point?
      fulfillment_type == 'pickup_point'
    end

    # Whether this method delivers to a customer shipping address —
    # answered by the fulfillment provider (digital and the pickup kinds
    # are address-free; custom providers default to requiring one).
    def requires_address?
      provider.requires_address?
    end

    # Whether this method can serve a package sourced from the given stock
    # location — answered by the fulfillment provider (shipping/digital are
    # location-agnostic; merchant pickup requires an eligible counter).
    def serves_location?(stock_location)
      provider.serves_location?(self, stock_location)
    end

    # The FulfillmentProvider strategy handling this method's fulfillments.
    # Falls back to Manual for rows created before the 6.0 backfill ran.
    def provider
      @provider ||= (fulfillment_provider.presence || 'Spree::FulfillmentProvider::Manual').constantize.new
    end

    # Flat-payload writer for `rules`, so one PATCH saves the method and its
    # conditions together. See
    # {Spree::TypedAssociations#assign_typed_association}.
    def rules=(rows)
      assign_typed_association(:delivery_method_rules, rows)
    end

    def pending_rules?
      @pending_delivery_method_rules.present?
    end

    # AND over the method's active rules; no rules = eligible everywhere.
    # Evaluated in the Estimator's method filter — the single seam every rate
    # consumer (checkout, routing, cart estimates) flows through.
    #
    # @param package [Spree::Stock::Package]
    # @return [Boolean]
    def eligible_for_package?(package)
      delivery_method_rules.select(&:active).all? { |rule| rule.eligible?(package) }
    end

    # Stock locations this method can fulfill from. For pickup methods an
    # empty set means every active pickup-enabled location qualifies.
    #
    # @return [ActiveRecord::Relation<Spree::StockLocation>]
    def available_pickup_locations
      configured = pickup_locations.merge(Spree::StockLocation.active)
      configured.exists? ? configured : Spree::StockLocation.active.pickup_enabled
    end

    # The third-party pickup point network behind a pickup_point method.
    #
    # @return [Spree::PickupPointProvider::Base, nil]
    def pickup_point_provider_instance
      @pickup_point_provider_instance ||= pickup_point_provider.presence&.constantize&.new
    end

    def self.calculators
      # calculator registry key keeps its historical name
      spree_calculators.shipping_methods.
        select { |c| c.to_s.constantize < Spree::ShippingCalculator }
    end

    # Whether this method may be quoted for the given audience. The
    # backoffice sees every method; the storefront only customer-facing ones.
    # An unrecognized audience raises rather than silently quoting storefront
    # rates — a typo must not narrow the offer set unnoticed.
    #
    # @param audience [Symbol, Integer] {STOREFRONT} or {BACKOFFICE}; the
    #   legacy DISPLAY_ON_* integers are accepted until 6.1
    # @return [Boolean]
    def available_to?(audience)
      case self.class.normalize_audience(audience)
      when BACKOFFICE then true
      else storefront_visible?
      end
    end

    # Maps an audience onto {STOREFRONT}/{BACKOFFICE}, accepting the legacy
    # DISPLAY_ON_* integers so callers holding the old constants keep working
    # until 6.1. Anything else raises — a typo must not silently quote
    # storefront-only rates.
    #
    # @param audience [Symbol, Integer]
    # @return [Symbol]
    def self.normalize_audience(audience)
      case audience
      when STOREFRONT, BACKOFFICE then audience
      when DISPLAY_ON_FRONT_END, DISPLAY_ON_BACK_END
        Spree::Deprecation.warn("Spree::DeliveryMethod::DISPLAY_ON_* audience filters are deprecated and will be removed in Spree 6.1. Use #{STOREFRONT.inspect} / #{BACKOFFICE.inspect} instead.")
        audience == DISPLAY_ON_BACK_END ? BACKOFFICE : STOREFRONT
      else
        raise ArgumentError, "unknown delivery audience #{audience.inspect} (expected #{STOREFRONT.inspect} or #{BACKOFFICE.inspect})"
      end
    end

    # @deprecated Use {#available_to?} with {STOREFRONT}/{BACKOFFICE};
    #   removed in 6.1.
    def available_to_display?(display_filter)
      Spree::Deprecation.warn('Spree::DeliveryMethod#available_to_display? is deprecated and will be removed in Spree 6.1. Use #available_to?(Spree::DeliveryMethod::STOREFRONT / BACKOFFICE) instead.')
      available_to?(display_filter)
    end

    def delivery_range
      return unless estimated_transit_business_days_min || estimated_transit_business_days_max

      if estimated_transit_business_days_min == estimated_transit_business_days_max
        estimated_transit_business_days_min.to_s
      else
        [estimated_transit_business_days_min, estimated_transit_business_days_max].compact.join("-")
      end
    end

    def display_estimated_price
      return unless calculator

      @display_estimated_price ||= begin
        calculator.description + ': ' +

        if calculator.is_a?(Spree::Calculator::Shipping::FlatRate)
          if calculator.preferred_amount == 0
            Spree.t(:free)
          else
            Spree::Money.new(calculator.preferred_amount, { currency: calculator.preferred_currency }).to_s
          end
        elsif calculator.is_a?(Spree::Calculator::Shipping::FlexiRate)
          Spree::Money.new(calculator.preferred_first_item, { currency: calculator.preferred_currency }).to_s
        elsif calculator.is_a?(Spree::Calculator::Shipping::FlatPercentItemTotal)
          ActionController::Base.helpers.number_to_percentage(calculator.preferred_flat_percent, precision: 2)
        else
          ''
        end
      end
    end

    # Returns true if the delivery method delivers digitally
    #
    # @return [Boolean]
    def digital?
      fulfillment_type == 'digital'
    end

    # @deprecated Use {#storefront_visible}; removed in 6.1.
    def display_on
      Spree::Deprecation.warn('Spree::DeliveryMethod#display_on is deprecated and will be removed in Spree 6.1. Use #storefront_visible instead.')
      storefront_visible? ? 'both' : 'back_end'
    end

    # @deprecated Use {#storefront_visible=}; removed in 6.1.
    def display_on=(value)
      Spree::Deprecation.warn('Spree::DeliveryMethod#display_on= is deprecated and will be removed in Spree 6.1. Use #storefront_visible= instead.')
      self.storefront_visible = value.to_s != 'back_end'
    end

    private

    def apply_pending_rules
      flush_pending_typed_association(:delivery_method_rules)
    end
  end
end
