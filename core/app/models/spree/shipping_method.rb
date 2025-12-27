module Spree
  class ShippingMethod < Spree.base_class
    acts_as_paranoid
    include Spree::CalculatedAdjustments
    include Spree::Metafields
    include Spree::Metadata
    include Spree::DisplayOn
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end
    include Spree::MemoizedData

    extend Spree::DisplayMoney

    MEMOIZED_METHODS = %w[display_estimated_price digital?]

    # Used for #refresh_rates
    DISPLAY_ON_FRONT_END = 1
    DISPLAY_ON_BACK_END = 2

    default_scope { where(deleted_at: nil) }

    has_many :shipping_method_categories, dependent: :destroy
    has_many :shipping_categories, through: :shipping_method_categories
    has_many :shipping_rates, inverse_of: :shipping_method
    has_many :shipments, through: :shipping_rates

    has_many :shipping_method_zones, class_name: 'Spree::ShippingMethodZone',
                                     foreign_key: 'shipping_method_id'
    has_many :zones, through: :shipping_method_zones, class_name: 'Spree::Zone'

    belongs_to :tax_category, -> { with_deleted }, class_name: 'Spree::TaxCategory', optional: true

    validates :name, :display_on, presence: true
    validates :estimated_transit_business_days_min, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
    validates :estimated_transit_business_days_max, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
    validate :at_least_one_shipping_category

    scope :digital, lambda {
                      joins(:calculator).where(spree_calculators: { type: Spree::Calculator::Shipping::DigitalDelivery.to_s })
                    }

    scope :search_by_name, ->(query) { where(arel_table[:name].lower.matches("%#{query}%")) }

    def include?(address)
      return true unless requires_zone_check?
      return false unless address

      zones.includes(:zone_members).any? do |zone|
        zone.include?(address)
      end
    end

    def requires_zone_check?
      !calculator.is_a?(Spree::Calculator::Shipping::DigitalDelivery)
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

    def self.calculators
      spree_calculators.send(model_name_without_spree_namespace).
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

    # Returns true if the shipping method is digital
    #
    # @return [Boolean]
    def digital?
      @digital ||= calculator.is_a?(Spree::Calculator::Shipping::DigitalDelivery)
    end

    private

    # Some shipping methods are only meant to be set via backend
    def frontend?
      display_on.in?(['both', 'front_end'])
    end

    def backend?
      display_on.in?(['both', 'back_end'])
    end

    def at_least_one_shipping_category
      if shipping_categories.empty?
        errors.add(:base, :required_shipping_category)
      end
    end
  end
end
