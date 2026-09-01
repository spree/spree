module Spree
  class DeliveryMethod < Spree.base_class
    has_prefix_id :dm

    acts_as_paranoid
    include Spree::SingleStoreResource
    include Spree::CalculatedAdjustments
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::MemoizedData
    include Spree::TypedAssociations

    extend Spree::DisplayMoney

    MEMOIZED_METHODS = %w[display_estimated_price]

    # Audience a rate refresh is quoting for: the storefront sees only
    # customer-facing methods, the backoffice sees every method.
    STOREFRONT = :storefront
    BACKOFFICE = :backoffice

    # Quoting strategy used when +rate_provider+ is blank.
    DEFAULT_RATE_PROVIDER = 'Spree::DeliveryRateProvider::Internal'.freeze

    # Dispatch strategy used when +fulfillment_provider+ is blank.
    DEFAULT_FULFILLMENT_PROVIDER = 'Spree::FulfillmentProvider::Manual'.freeze

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
    has_many :services, -> { order(:position) }, class_name: 'Spree::DeliveryMethodService',
             dependent: :destroy, inverse_of: :delivery_method
    has_many :pickup_locations, through: :delivery_method_stock_locations, source: :stock_location

    # The profile this method belongs to — the sole path a product's package
    # reaches it through. Within the profile the method sits in an origin
    # group (which origins offer it); the optional zone narrows destinations
    # and must share the method's group.
    belongs_to :delivery_profile, class_name: 'Spree::DeliveryProfile', inverse_of: :delivery_methods
    belongs_to :delivery_origin_group, class_name: 'Spree::DeliveryOriginGroup', inverse_of: :delivery_methods
    belongs_to :delivery_zone, class_name: 'Spree::DeliveryZone', optional: true

    belongs_to :tax_category, -> { with_deleted }, class_name: 'Spree::TaxCategory', optional: true

    # On a marketplace, who quotes and ships with this method. Nil is the
    # operator's own method — the only kind that existed before sellers, and
    # the only kind a first-party package is ever offered
    # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
    belongs_to :seller, class_name: 'Spree::Seller', optional: true, inverse_of: :delivery_methods

    attribute :storefront_visible, :boolean, default: true

    # Every method carries a calculator — the Estimator consults its
    # `available?` even when a provider sets the price. Methods whose rate
    # provider quotes live rates (and pickup/digital methods) default to a
    # free rate, so neither the API nor the dashboard has to send one.
    before_validation :ensure_calculator, on: :create
    # Mirrors product stamping: a method created without an explicit profile
    # joins the store's default one, landing in the profile's default origin
    # group unless one is named (a zone names one implicitly).
    before_validation :assign_default_delivery_profile, on: :create
    before_validation :assign_default_origin_group, on: :create
    after_save :apply_pending_rules, if: :pending_rules?
    after_save :apply_pending_services, if: :pending_services?
    attribute :fulfillment_provider, :string, default: 'Spree::FulfillmentProvider::Manual'

    # Methods whose fulfillment provider satisfies the predicate — behavior
    # queries route through provider classes, never string vocabularies.
    scope :with_provider, ->(predicate) {
      where(fulfillment_provider: Spree.fulfillment_providers.select(&predicate).map(&:to_s))
    }

    # Customer-facing methods vs backoffice-only ones (manual courier entry,
    # internal freight). The backoffice always sees every method.
    scope :storefront_visible, -> { where(storefront_visible: true) }
    scope :admin_only, -> { where(storefront_visible: false) }

    # The operator's own methods, and the sellers' own.
    scope :first_party, -> { where(seller_id: nil) }
    scope :for_seller, ->(seller) { where(seller_id: seller.respond_to?(:id) ? seller.id : seller) }
    # Marketplace methods the operator has opened up to sellers' packages.
    scope :shared_with_sellers, -> { first_party.where(available_to_sellers: true) }

    # Every method a package sourced from the given seller's location may be
    # quoted by: that seller's own, plus whatever the operator shares. A
    # first-party package (nil seller) sees the operator's methods only —
    # including the shared ones, which are the operator's to begin with.
    #
    # @param seller [Spree::Seller, nil]
    # @return [ActiveRecord::Relation<Spree::DeliveryMethod>]
    scope :available_to_seller, ->(seller) {
      seller.nil? ? first_party : where(seller_id: seller.id).or(shared_with_sellers)
    }

    # Legacy association names — removed in 6.1.
    has_many :shipping_rates, class_name: 'Spree::DeliveryRate', foreign_key: :delivery_method_id, deprecated: true
    has_many :shipments, through: :delivery_rates, source: :fulfillment, deprecated: true

    # Real columns, so admin clients filter them directly — no ransacker
    # needed. `seller_id` is what the operator's list filters by to see one
    # seller's methods, or (blank) the marketplace's own.
    self.whitelisted_ransackable_attributes = %w[storefront_visible available_to_sellers seller_id]
    self.whitelisted_ransackable_associations = %w[seller]

    validates :name, presence: true
    validates :storefront_visible, inclusion: { in: [true, false] }
    validate :delivery_zone_must_belong_to_profile,
             if: -> { delivery_zone_id_changed? || delivery_profile_id_changed? }
    validate :origin_group_must_match,
             if: -> { delivery_origin_group_id_changed? || delivery_zone_id_changed? || delivery_profile_id_changed? }
    validates :estimated_transit_business_days_min, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
    validates :estimated_transit_business_days_max, numericality: { greater_than_or_equal_to: 1 }, allow_nil: true
    # Same reasoning as fulfillment_type: an unregistered provider is a typo
    # that would raise at quote time, deep inside checkout. Blank is valid —
    # it means the Internal provider.
    validates :rate_provider,
              inclusion: { in: -> (_record) { Spree.delivery_rate_providers.map(&:to_s) } },
              allow_blank: true,
              if: :rate_provider_changed?
    # The admin picker filters on availability, but a direct API write must
    # not save a provider whose integration isn't connected — that breaks
    # quoting at checkout, not at save time where the admin can see it.
    validate :rate_provider_must_be_available, if: :rate_provider_changed?
    # Providers declare the fulfillment types they handle; a mismatch would
    # only surface at checkout (no rates) or at ship time (no dispatch),
    # so reject it where the admin can still see why.
    # The profile kind gates composition (a Digital profile only accepts
    # digital-provider methods), and an address-requiring rate provider (a
    # carrier) can only price methods that ship to an address.
    validate :profile_must_accept_provider,
             if: -> { fulfillment_provider_changed? || delivery_profile_id_changed? }
    validate :rate_provider_must_ship,
             if: -> { rate_provider_changed? || fulfillment_provider_changed? }
    validate :seller_must_belong_to_store, if: -> { seller_id_changed? || store_id_changed? }
    # Carrier credentials live on the store-scoped `Spree::Integration`, so a
    # seller's method prices through the internal rate provider and ships
    # through the manual one. Refused at save time rather than surfacing as a
    # missing rate at checkout.
    validate :seller_methods_use_own_providers,
             if: -> { seller_id.present? && (seller_id_changed? || rate_provider_changed? || fulfillment_provider_changed?) }
    # Sharing is the operator's switch to throw. A seller cannot hand their
    # own method to the rest of the marketplace.
    validate :only_marketplace_methods_are_shared, if: -> { seller_id_changed? || available_to_sellers_changed? }

    scope :digital, -> { with_provider(:digital?) }

    scope :search_by_name, ->(query) { where(arel_table[:name].lower.matches("%#{query}%")) }

    def include?(address)
      return true unless requires_zone_check?
      return false unless address
      return true if delivery_zone.nil?

      delivery_zone.include?(address)
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
      provider_class.pickup?
    end

    # Whether this method belongs to a seller rather than the marketplace.
    #
    # @return [Boolean]
    def seller_owned?
      seller_id.present?
    end

    def ensure_calculator
      self.calculator ||= Spree::Calculator::Shipping::FlatRate.new(preferred_amount: 0)
    end

    def assign_default_delivery_profile
      self.delivery_profile ||= store&.default_delivery_profile
    end

    # The zone's group wins when a zone is set (they must agree anyway);
    # zoneless methods fall back to the profile's default group.
    def assign_default_origin_group
      self.delivery_origin_group ||= delivery_zone&.delivery_origin_group || delivery_profile&.default_origin_group
    end

    def origin_group_must_match
      if delivery_origin_group.present? && delivery_profile.present? &&
          delivery_origin_group.delivery_profile_id != delivery_profile_id
        errors.add(:delivery_origin_group, :invalid)
      end

      return if delivery_zone.nil? || delivery_origin_group.nil?
      return if delivery_zone.delivery_origin_group_id == delivery_origin_group_id

      errors.add(:delivery_zone, :does_not_belong_to_origin_group,
                 message: Spree.t('errors.messages.delivery_zone_not_in_origin_group'))
    end

    def pickup_point?
      provider_class.pickup_point?
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
    # Falls back to Manual when the stored provider no longer resolves, for
    # the same reason as {#rate_provider_class} — an uninstalled gem must not
    # raise at ship time.
    #
    # @return [Class]
    def provider_class
      (fulfillment_provider.presence || DEFAULT_FULFILLMENT_PROVIDER).safe_constantize ||
        DEFAULT_FULFILLMENT_PROVIDER.constantize
    end

    def provider
      @provider ||= provider_class.new
    end

    # The DeliveryRateProvider strategy quoting this method. Blank means the
    # Internal (calculator-backed) provider, so untouched rows keep their
    # existing pricing.
    #
    # @return [Spree::DeliveryRateProvider::Base]
    def rate_provider_instance
      @rate_provider_instance ||= rate_provider_class.new(self)
    end

    # Falls back to the default when the stored provider no longer resolves —
    # a gem can be uninstalled while its rows remain, and raising here would
    # surface as a checkout error rather than a missing carrier option.
    #
    # @return [Class]
    def rate_provider_class
      (rate_provider.presence || DEFAULT_RATE_PROVIDER).safe_constantize || DEFAULT_RATE_PROVIDER.constantize
    end


    # Flat-payload writer for `rules`, so one PATCH saves the method and its
    # conditions together. See
    # {Spree::TypedAssociations#assign_typed_association}.
    def rules=(rows)
      assign_typed_association(:delivery_method_rules, rows)
    end

    # Flat-payload writer for carrier service rows, so one PATCH saves the
    # method and its services together. Rows update by id, match by
    # (carrier, service), or create; rows omitted from the payload are
    # destroyed. Assigning model instances (or an empty array) falls through
    # to the standard association writer.
    def services=(rows)
      first = Array(rows).first
      return super if first.nil? || first.is_a?(Spree.base_class)

      pending = Array(rows).map { |row| row.to_h.with_indifferent_access }
      if new_record?
        @pending_services = pending
      else
        reconcile_services(pending)
      end
    end

    def pending_services?
      @pending_services.present?
    end

    # The service row matching an estimate's carrier + service identity.
    #
    # @param estimate [Spree::DeliveryRateProvider::Estimate]
    # @return [Spree::DeliveryMethodService, nil]
    def service_for(estimate)
      services.detect { |row| row.carrier == estimate.carrier && row.service == estimate.service_level }
    end

    # Whether the method offers this estimate: no service rows means every
    # service the provider returns, rows mean exactly those.
    #
    # @param estimate [Spree::DeliveryRateProvider::Estimate]
    # @return [Boolean]
    def offers_service?(estimate)
      services.empty? || service_for(estimate).present?
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
    # empty set means every active pickup-enabled location of the method's
    # own store qualifies — never other stores' counters.
    #
    # @return [ActiveRecord::Relation<Spree::StockLocation>]
    def available_pickup_locations
      configured = pickup_locations.merge(Spree::StockLocation.active)
      configured.exists? ? configured : store.stock_locations.active.pickup_enabled
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
      provider_class.digital?
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

    def apply_pending_services
      pending = @pending_services
      @pending_services = nil
      reconcile_services(pending)
    end

    def reconcile_services(rows)
      kept_ids = rows.filter_map do |row|
        record =
          if row[:id].present?
            id = Spree::PrefixedId.prefixed_id?(row[:id]) ? Spree::PrefixedId.decode_prefixed_id(row[:id]) : row[:id]
            services.find_by(id: id)
          end
        record ||= services.find_or_initialize_by(carrier: row[:carrier], service: row[:service])
        record.assign_attributes(row.slice(:carrier, :service, :label, :markup_flat, :markup_percent, :position).to_h)
        record.save!
        record.id
      end

      services.where.not(id: kept_ids).destroy_all
      services.reset
    end

    # Only meaningful for registered providers — the inclusion validation
    # already rejects anything else, so an unresolvable name must not raise
    # here as well.
    def delivery_zone_must_belong_to_profile
      return if delivery_zone.nil?
      return if delivery_zone.delivery_profile_id == delivery_profile_id

      errors.add(:delivery_zone, :does_not_belong_to_profile,
                 message: Spree.t('errors.messages.delivery_zone_not_in_profile'))
    end

    def profile_must_accept_provider
      return if delivery_profile.nil?
      return if delivery_profile.accepts_provider?(provider_class)

      errors.add(
        :fulfillment_provider,
        Spree.t('errors.messages.profile_does_not_accept_provider',
                provider: provider_class.provider_name, profile: delivery_profile.name)
      )
    end

    # A carrier quotes real shipments, so it can only price methods whose
    # fulfillment provider ships to an address.
    def rate_provider_must_ship
      return unless rate_provider_class.requires_address?
      return if provider_class.new.requires_address?

      errors.add(
        :rate_provider,
        Spree.t('errors.messages.rate_provider_requires_shipping',
                provider: rate_provider_class.provider_name)
      )
    end

    def rate_provider_must_be_available
      return if rate_provider.blank?
      return unless Spree.delivery_rate_providers.map(&:to_s).include?(rate_provider)
      return if rate_provider_class.available_for_store?(store)

      errors.add(:rate_provider, Spree.t('errors.messages.rate_provider_unavailable'))
    end

    def seller_must_belong_to_store
      return if seller.nil? || store.nil?
      return if seller.store_id == store_id

      errors.add(:seller, :invalid)
    end

    def seller_methods_use_own_providers
      unless rate_provider.blank? || rate_provider == DEFAULT_RATE_PROVIDER
        errors.add(:rate_provider, Spree.t('errors.messages.seller_delivery_method_provider'))
      end

      return if fulfillment_provider.blank? || fulfillment_provider == DEFAULT_FULFILLMENT_PROVIDER

      errors.add(:fulfillment_provider, Spree.t('errors.messages.seller_delivery_method_provider'))
    end

    def only_marketplace_methods_are_shared
      return unless available_to_sellers? && seller_owned?

      errors.add(:available_to_sellers, Spree.t('errors.messages.seller_delivery_method_not_shareable'))
    end
  end
end
