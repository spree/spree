module Spree
  class DeliveryMethod < Spree.base_class
    has_prefix_id :dm

    acts_as_paranoid
    include Spree::SingleStoreResource
    include Spree::CalculatedAdjustments
    include Spree::Metafields
    include Spree::Metadata
    include Spree::DisplayOn
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end
    include Spree::MemoizedData

    extend Spree::DisplayMoney

    MEMOIZED_METHODS = %w[display_estimated_price]

    # Used for #refresh_rates
    DISPLAY_ON_FRONT_END = 1
    DISPLAY_ON_BACK_END = 2

    default_scope { where(deleted_at: nil) }

    has_many :shipping_method_categories, foreign_key: :shipping_method_id, dependent: :destroy
    has_many :shipping_categories, through: :shipping_method_categories
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

    attribute :display_on, :string, default: 'both'
    attribute :fulfillment_type, :string, default: 'shipping'

    # Every method rates through a calculator; pickup/digital methods default
    # to free so API/dashboard creation doesn't have to send one.
    before_validation :ensure_calculator, on: :create
    attribute :fulfillment_provider, :string, default: 'Spree::FulfillmentProvider::Manual'

    scope :by_fulfillment_type, ->(type) { where(fulfillment_type: type) }

    # Legacy association names — removed in 6.1.
    has_many :shipping_rates, class_name: 'Spree::DeliveryRate', foreign_key: :delivery_method_id, deprecated: true
    has_many :shipments, through: :delivery_rates, source: :fulfillment, deprecated: true
    has_many :zones, through: :delivery_method_zones, source: :delivery_zone, deprecated: true

    validates :name, :display_on, :fulfillment_type, presence: true
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

    def available_to_display?(display_filter)
      (frontend? && display_filter == DISPLAY_ON_FRONT_END) ||
        (backend? && display_filter == DISPLAY_ON_BACK_END)
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

    private

    # Some shipping methods are only meant to be set via backend
    def frontend?
      display_on.in?(['both', 'front_end'])
    end

    def backend?
      display_on.in?(['both', 'back_end'])
    end
  end
end
