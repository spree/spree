module Spree
  class Address < Spree.base_class
    has_prefix_id :addr  # Spree-specific: address

    require 'validates_zipcode'

    include Spree::HasCustomFields
    include Spree::Metadata

    serialize :preferences, type: Hash, coder: YAML, default: {}

    NO_ZIPCODE_ISO_CODES ||= [
      'AO', 'AG', 'AW', 'BS', 'BZ', 'BJ', 'BM', 'BO', 'BW', 'BF', 'BI', 'CM', 'CF', 'KM', 'CG',
      'CD', 'CK', 'CUW', 'CI', 'DJ', 'DM', 'GQ', 'ER', 'FJ', 'TF', 'GAB', 'GM', 'GH', 'GD', 'GN',
      'GY', 'HK', 'IE', 'KI', 'KP', 'LY', 'MO', 'MW', 'ML', 'MR', 'NR', 'AN', 'NU', 'KP', 'PA',
      'QA', 'RW', 'KN', 'LC', 'ST', 'SC', 'SL', 'SB', 'SO', 'SR', 'SY', 'TZ', 'TL', 'TK', 'TG',
      'TO', 'TV', 'UG', 'AE', 'VU', 'YE', 'ZW'
    ].freeze

    # The required states listed below match those used by PayPal and Shopify.
    STATES_REQUIRED = [
      'AU', 'AE', 'BR', 'CA', 'CN', 'ES', 'HK', 'IE', 'IN',
      'IT', 'MY', 'MX', 'NZ', 'PT', 'RO', 'TH', 'US', 'ZA'
    ].freeze

    # we're not freezing this on purpose so developers can extend and manage
    # those attributes depending of the logic of their applications
    ADDRESS_FIELDS = %w(firstname lastname company address1 address2 city state zipcode country phone)
    EXCLUDED_KEYS_FOR_COMPARISON = %w(id updated_at created_at deleted_at label customer_id metadata)
    if defined?(Spree::Security::Addresses)
      include Spree::Security::Addresses
    end

    scope :not_deleted, -> { where(deleted_at: nil) }

    # Matches a subdivision by code or by name. Only the code is stored, so a
    # name is resolved to the codes it could mean before querying.
    scope :by_state_name_or_abbr, lambda { |state_name|
      codes = Spree::IsoData.countries.filter_map do |country|
        Spree::IsoData.subdivision_code(country.alpha2, state_name)
      end.uniq

      where(state_abbr: ([state_name] + codes).uniq)
    }

    scope :not_quick_checkout, -> { where(quick_checkout: false) }

    # Geography is reference data, so these read through the registry rather
    # than being associations. Assigning either one sets its code.
    def country
      @country = nil if @country && @country.iso != country_iso
      @country ||= Spree::Country.by_iso(country_iso) if country_iso.present?
    end

    def country=(value)
      @country = value
      self[:country_iso] = value&.iso
    end

    def state
      @state = nil if @state && (@state.abbr != state_abbr || @state.country_iso != country_iso)
      @state ||= Spree::State.resolve(country_iso, state_abbr) if country_iso.present? && state_abbr.present?
    end

    def state=(value)
      @state = value
      self[:state_abbr] = value&.abbr
      self[:country_iso] ||= value.country_iso if value
    end
    # we need a safe operator here as Address is added to custom_field_enabled_resources in Engine
    belongs_to :customer, class_name: Spree.customer_class&.name, optional: true, touch: true
    include Spree::DeprecatedCustomerAlias

    has_many :fulfillments, class_name: 'Spree::Fulfillment', inverse_of: :address
    has_many :shipments, class_name: 'Spree::Fulfillment', foreign_key: :address_id, deprecated: true

    after_initialize :set_default_values, if: -> { new_record? && customer.present? }

    before_validation :normalize_country
    before_validation :normalize_state
    before_validation :clear_invalid_state_entities, if: -> { country.present? }, on: :update

    after_create :set_user_attributes, if: -> { customer.present? }

    after_commit :async_geocode

    with_options presence: true do
      validates :firstname, :lastname, if: :require_name?
      validates :address1, if: :require_street?
      validates :city, :country
      validates :zipcode, if: :require_zipcode?
      validates :phone, if: :require_phone?
      validates :company, if: :require_company?
    end

    validate :state_validate, :postal_code_validate
    validate :address_validators, on: [:create, :update]

    validates :label, uniqueness: { conditions: -> { where(deleted_at: nil) },
                                    scope: :customer_id,
                                    case_sensitive: false,
                                    allow_blank: true,
                                    allow_nil: true }

    def address_validators
      Spree.validators.addresses.each do |validator|
        validates_with validator
      end
    end

    delegate :name, :iso3, :iso_name, to: :country, prefix: true, allow_nil: true

    alias_attribute :postal_code, :zipcode
    alias_attribute :first_name, :firstname
    alias_attribute :last_name, :lastname

    # The single home for postal-code normalization (delivery-zone matching) —
    # don't scatter zipcode munging elsewhere.
    # @param value [String, nil]
    # @return [String] value with spaces/dashes stripped, upcased
    def self.normalize_zipcode(value)
      value.to_s.gsub(/[\s-]/, '').upcase
    end

    # @return [String] this address's zipcode, normalized via {.normalize_zipcode}
    def normalized_zipcode
      self.class.normalize_zipcode(zipcode)
    end

    # Normalizes a params hash for query builders like +find_or_create_by+,
    # which match on exactly the keys they are given. Codes are upcased so a
    # lookup finds the row a save would have written, the redundant foreign
    # keys are dropped, and a +state_name+ that names a real subdivision
    # becomes the code that a saved address would hold.
    #
    # Assignment does not need this — the writers and their +before_validation+
    # callbacks resolve both halves.
    #
    # @param params [Hash]
    # @return [Hash]
    def self.resolve_geo_params(params)
      params = params.to_h.symbolize_keys
      params.delete(:country_id)
      params.delete(:state_id)

      country_iso = params[:country_iso].presence&.to_s&.upcase
      params[:country_iso] = country_iso if country_iso

      if params[:state_abbr].present?
        params[:state_abbr] = params[:state_abbr].to_s.upcase
      elsif country_iso && params[:state_name].present?
        matched = Spree::IsoData.subdivision_code(country_iso, params[:state_name])

        if matched
          params[:state_abbr] = matched
          params.delete(:state_name)
        end
      end

      params
    end

    # +country_iso+ and +state_abbr+ are the columns the address stores its
    # geography in; +country+ and +state+ read through them.
    def country_iso=(value)
      super(value.presence&.to_s&.upcase)
    end

    def state_abbr=(value)
      super(value.presence&.to_s&.upcase)
    end

    self.whitelisted_ransackable_attributes = ADDRESS_FIELDS + %w[country_iso state_abbr]
    self.whitelisted_ransackable_associations = %w[customer]

    def self.required_fields
      Spree::Address.validators.map do |v|
        v.is_a?(ActiveModel::Validations::PresenceValidator) ? v.attributes : []
      end.flatten
    end

    # In 6.0 these become real columns on Address, replacing User#bill_address_id / ship_address_id.
    # For now they delegate to the User FK so the API shape is stable.
    def is_default_billing?
      customer.present? && id == customer.bill_address_id
    end
    alias_method :is_default_billing, :is_default_billing?

    def is_default_shipping?
      customer.present? && id == customer.ship_address_id
    end
    alias_method :is_default_shipping, :is_default_shipping?

    # first_name / last_name aliases are defined via alias_attribute above

    def full_name
      "#{firstname} #{lastname}".strip
    end

    def state_text
      state_abbr.presence || state.try(:name) || state_name
    end

    def state_name_text
      state_name.present? ? state_name : state&.name
    end

    def street
      [address1, address2].join(' ')
    end

    def to_s
      [
        full_name,
        company,
        address1,
        address2,
        "#{city}, #{state_text} #{zipcode}",
        country.to_s
      ].reject(&:blank?).map { |attribute| ERB::Util.html_escape(attribute) }.join('<br/>')
    end

    def clone
      self.class.new(value_attributes)
    end

    def ==(other)
      return false unless other&.respond_to?(:value_attributes)

      value_attributes == other.value_attributes
    end

    def value_attributes
      attributes.except(*EXCLUDED_KEYS_FOR_COMPARISON)
    end

    # A country alone doesn't make an address — a new one is pre-filled with the
    # store's default, so both the code and the association are ignored here.
    def empty?
      attributes.except('id', 'created_at', 'updated_at', 'country_id', 'country_iso').all? { |_, v| v.nil? }
    end

    # Generates an address hash for payment gateway options
    def gateway_hash
      {
        name: full_name,
        address1: address1,
        address2: address2,
        city: city,
        state: state_text,
        zip: zipcode,
        country: country.try(:iso),
        phone: phone
      }
    end
    alias_method :active_merchant_hash, :gateway_hash

    def require_phone?
      # We want to collect phone number for quick checkout but not to validate it
      # as it's not available before payment by browser.
      !quick_checkout && store_preference(:address_requires_phone, false)
    end

    def require_zipcode?
      !quick_checkout && (country ? country.zipcode_required? : true)
    end

    def require_name?
      !quick_checkout
    end

    def require_company?
      # Only meaningful when the field is on the form at all — requiring a
      # value the customer is never shown would make checkout unfinishable.
      !quick_checkout && show_company_address_field? && store_preference(:address_requires_company, false)
    end

    def require_street?
      !quick_checkout
    end

    def show_company_address_field?
      store_preference(:company_field_enabled, false)
    end

    def editable?
      new_record? || Order.complete.where('bill_address_id = ? OR ship_address_id = ?', id, id).none?
    end

    def can_be_deleted?
      shipments.empty? && Order.complete.where('bill_address_id = ? OR ship_address_id = ?', id, id).none?
    end

    def check
      attrs = attributes.except('id', 'updated_at', 'created_at')
      the_same_address = customer&.addresses&.find_by(attrs)
      the_same_address || self
    end

    def destroy
      assign_new_default_address_to_user

      if can_be_deleted?
        unassign_from_incomplete_orders
        super
      else
        update_column :deleted_at, Time.current
      end
    end

    def async_geocode
      Spree::Addresses::GeocodeAddressJob.perform_later(id) if should_geocode?
    end

    def geocoder_address
      @geocoder_address ||= [street, city, state_text, country.to_s].compact.map(&:strip).join(', ')
    end

    private

    # Addresses carry no store association, so store-scoped settings resolve
    # through the ambient store. Outside a request (console, seeds, a job that
    # forgets to set the store) there may be none, so callers pass the
    # preference default explicitly.
    def store_preference(name, fallback)
      store = Spree::Current.store
      return fallback if store.nil?

      store.get_preference(name)
    end

    def should_geocode?
      Spree::Config[:geocode_addresses] && (
        saved_changes.key?(:address1) || saved_changes.key?(:city) ||
        saved_changes.key?(:state_abbr) || saved_changes.key?(:country_iso)
      )
    end

    def set_default_values
      self.firstname ||= customer.first_name
      self.lastname ||= customer.last_name
      self.phone ||= customer.phone
    end

    # The ISO code is what the address stores; the association is kept in step
    # with it for the one release it still exists. Assigning +country+ directly
    # is equally supported — whichever half was set fills in the other.
    def normalize_country
      # Reads the column, not +country_iso+, whose association fallback would
      # make this branch always taken once a country is assigned.
      submitted_iso = self[:country_iso].presence

      if submitted_iso.present?
        self.country = Spree::Country.by_iso(submitted_iso) unless country&.iso == submitted_iso
        # An unrecognised code leaves no country to validate against; the
        # presence validation on +country+ reports it.
        self[:country_iso] = country.iso if country
      elsif country.present?
        self[:country_iso] = country.iso
      end
    end

    # Resolves the subdivision code from whichever handle the caller supplied:
    # +state_abbr+ (which may be a retired code), or a +state_name+ that names
    # a real subdivision of this country. A name matching nothing is left
    # alone — countries without subdivisions keep it as free text, and
    # +state_validate+ decides whether that is acceptable.
    def normalize_state
      return if country_iso.blank?

      submitted_abbr = self[:state_abbr].presence

      if submitted_abbr.present?
        resolved = Spree::IsoData.subdivision_code(country_iso, submitted_abbr)

        # A code that means nothing in this country is stale — it came from the
        # country the address just moved off — so drop it and let the other
        # handles (a state_name, or nothing) decide.
        self[:state_abbr] = resolved
        return if resolved
      end

      return if state_name.blank?

      matched = Spree::IsoData.subdivision_code(country_iso, state_name)
      return if matched.blank?

      self[:state_abbr] = matched
      self.state_name = nil
    end

    def clear_state
      self.state = nil
      self[:state_abbr] = nil
    end

    def clear_state_name
      self.state_name = nil
    end

    def clear_invalid_state_entities
      # A subdivision that means nothing in this country was already dropped by
      # normalize_state; what is left is free text on a country that has no
      # subdivisions to match it against.
      return unless state_name.present? && !country.states_required? && country.states.empty?

      clear_state_name
    end

    def set_user_attributes
      if customer.name.blank?
        customer.first_name = firstname
        customer.last_name = lastname
      end
      customer.phone = customer.phone.presence || phone.presence

      customer.save! if customer.changed?
    end

    # normalize_state has already resolved the code, so what is left to check
    # is whether a country that requires a subdivision actually got one.
    def state_validate
      # Skip state validation without country (also required).
      # Whether a state is required is the country's call.
      return if country.blank?
      return unless country.states_required

      if state_abbr.present?
        clear_state_name
        return
      end

      # A name is only acceptable when it names nothing the country knows —
      # otherwise normalize_state would have turned it into a code.
      if state_name.present?
        errors.add(:state, :invalid) if country.states.any?
        return
      end

      errors.add :state, :blank
    end

    def postal_code_validate
      return if country.blank? || country_iso.blank? || !require_zipcode? || zipcode.blank?
      return unless ::ValidatesZipcode::CldrRegexpCollection::ZIPCODES_REGEX.keys.include?(country_iso.upcase.to_sym)

      formatted_zip = ::ValidatesZipcode::Formatter.new(
        zipcode: zipcode.to_s.strip,
        country_alpha2: country_iso.upcase
      ).format

      errors.add(:zipcode, :invalid) unless ::ValidatesZipcode.valid?(formatted_zip, country_iso.upcase)
    end

    def assign_new_default_address_to_user
      return unless customer

      customer.reload
      return if customer.bill_address != self && customer.ship_address != self

      last_address = assign_new_default_address_to_user_scope.find { |address| address.id != id && address.valid? }

      customer.bill_address = last_address if customer.bill_address == self
      customer.ship_address = last_address if customer.ship_address == self
      customer.save!
    end

    def assign_new_default_address_to_user_scope
      customer.addresses.not_quick_checkout.reorder(created_at: :desc)
    end

    def unassign_from_incomplete_orders
      orders = Spree::Order.incomplete.where(customer_id: customer_id)
      orders.where(ship_address_id: id).update_all(ship_address_id: nil, updated_at: Time.current)
      orders.where(bill_address_id: id).update_all(bill_address_id: nil, updated_at: Time.current)
    end
  end
end
