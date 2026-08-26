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
    EXCLUDED_KEYS_FOR_COMPARISON = %w(id updated_at created_at deleted_at label owner_type owner_id metadata)
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

      where(state_code: ([state_name] + codes).uniq)
    }

    scope :not_quick_checkout, -> { where(quick_checkout: false) }

    has_iso_geography

    # @deprecated The canonical names are +country_code+ and +state_code+,
    #   matching the tax tables. Kept because the Store API shipped
    #   +country_iso+ and +state_abbr+; both are removed in 6.1.
    alias_attribute :state_abbr, :state_code
    alias_attribute :country_iso, :country_code

    # Who the address belongs to: a customer's address book, a company node's,
    # or a seller's billing address. One relationship with three cardinalities,
    # so a further owner costs no schema change — and what the row requires
    # follows from the owner rather than from a subclass.
    #
    # Order and cart addresses have no owner: completion copies the attributes
    # onto a fresh row, and that snapshot belongs to the order, not to anyone's
    # book.
    belongs_to :owner, polymorphic: true, optional: true, touch: true


    has_many :fulfillments, class_name: 'Spree::Fulfillment', inverse_of: :address
    has_many :shipments, class_name: 'Spree::Fulfillment', foreign_key: :address_id, deprecated: true

    after_initialize :set_default_values, if: -> { new_record? && customer_owned? }

    before_validation :normalize_country
    before_validation :normalize_state
    before_validation :clear_invalid_state_entities, if: -> { country.present? }, on: :update

    after_create :set_user_attributes, if: -> { customer_owned? }

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
                                    scope: [:owner_type, :owner_id],
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

      # Legacy write names accepted until 6.1; the columns are country_code
      # and state_code.
      params[:state_code] = params.delete(:state_abbr) if params.key?(:state_abbr)
      params[:country_code] = params.delete(:country_iso) if params.key?(:country_iso)

      country_code = params[:country_code].presence&.to_s&.upcase
      params[:country_code] = country_code if country_code

      if params[:state_code].present?
        params[:state_code] = params[:state_code].to_s.upcase
      elsif country_code && params[:state_name].present?
        matched = Spree::IsoData.subdivision_code(country_code, params[:state_name])

        if matched
          params[:state_code] = matched
          params.delete(:state_name)
        end
      end

      params
    end

    # Finds an existing, undeleted address matching the given attributes, so a
    # customer re-entering an address they already have reuses that row rather
    # than accumulating duplicates. Geography is matched by code, and a state
    # given by name is resolved to the codes it could mean.
    #
    # @param attributes [Hash]
    # @return [Spree::Address, nil]
    def self.find_duplicate(attributes)
      attributes = resolve_geo_params(attributes.except(:id, :updated_at, :created_at))
      state_name = attributes[:state_name]

      scope = not_deleted.where(attributes.except(:state_name))
      scope = scope.by_state_name_or_abbr(state_name) if state_name.present?
      scope.first
    end

    self.whitelisted_ransackable_attributes = ADDRESS_FIELDS + %w[country_code state_code]
    self.whitelisted_ransackable_associations = %w[owner]

    def self.required_fields
      Spree::Address.validators.map do |v|
        v.is_a?(ActiveModel::Validations::PresenceValidator) ? v.attributes : []
      end.flatten
    end

    # The owner when it is a customer, so customer-specific behaviour (the
    # address book defaults, the profile back-fill) reads nil for a company's
    # or a seller's row and simply does not apply.
    #
    # @return [Object, nil]
    def customer_owner
      owner if customer_owned?
    end

    # @return [Boolean]
    def customer_owned?
      owner_type == Spree.customer_class.to_s
    end

    # @param kind [Symbol] :bill or :ship
    # @return [Integer, nil] the owner's chosen address of that kind
    def default_address_id(kind)
      return nil if owner.nil?
      return owner.public_send(:"#{kind}_address_id") if customer_owned?
      return owner.public_send(:"default_#{kind}_address_id") if owner.is_a?(Spree::Company)

      nil
    end

    # @deprecated The address's owner may be a customer, a company node or a
    #   seller, so {#owner} replaces the customer-only association. Removed in
    #   Spree 6.1.
    def user
      Spree::Deprecation.warn('Spree::Address#user is deprecated and will be removed in Spree 6.1. Use #owner instead.') if defined?(Spree::Deprecation)
      customer_owner
    end

    def user=(value)
      Spree::Deprecation.warn('Spree::Address#user= is deprecated and will be removed in Spree 6.1. Use #owner= instead.') if defined?(Spree::Deprecation)
      self.owner = value
    end

    def user_id
      Spree::Deprecation.warn('Spree::Address#user_id is deprecated and will be removed in Spree 6.1. Use #owner_id instead.') if defined?(Spree::Deprecation)
      owner_id if customer_owned?
    end

    # A company node's or a seller's address: nobody is named on it, and the
    # business is the part that cannot be left out.
    #
    # @return [Boolean]
    def business_owned?
      owner_type == 'Spree::Company' || owner_type == 'Spree::Seller'
    end

    # The company line. A stored value wins, so an order's copied address keeps
    # what it was sent with even after the node is renamed, and a member can
    # override the line for one site. An owned book entry with nothing stored
    # tracks its node's current name.
    #
    # @return [String, nil]
    def company
      stored = read_attribute(:company)
      return stored if stored.present?

      owner.name if owner.is_a?(Spree::Company)
    end

    # Whether the owner prefills with this address. Every owner keeps the
    # pointer itself — a customer on bill_address_id / ship_address_id, a
    # company node on its own two columns — so the answer is the same question
    # asked of whichever one owns the row.
    def is_default_billing?
      default_address_id(:bill) == id
    end
    alias_method :is_default_billing, :is_default_billing?

    def is_default_shipping?
      default_address_id(:ship) == id
    end
    alias_method :is_default_shipping, :is_default_shipping?

    # first_name / last_name aliases are defined via alias_attribute above

    def full_name
      "#{firstname} #{lastname}".strip
    end

    def state_text
      state_code.presence || state.try(:name) || state_name
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
      attributes.except('id', 'created_at', 'updated_at', 'country_id', 'country_code').all? { |_, v| v.nil? }
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

    # A business address names no person: a company site or a seller's billing
    # address has no contact to insist on, which is why the owner decides this
    # rather than a subclass.
    def require_name?
      !quick_checkout && !business_owned?
    end

    def require_company?
      return false if quick_checkout
      # A company node names itself, so the line is always answerable; a
      # seller's billing address is what a commission invoice is addressed to,
      # and that is the part which cannot be left out.
      return true if business_owned?

      # Only meaningful when the field is on the form at all — requiring a
      # value the customer is never shown would make checkout unfinishable.
      show_company_address_field? && store_preference(:address_requires_company, false)
    end

    def require_street?
      !quick_checkout
    end

    def show_company_address_field?
      return true if business_owned?

      store_preference(:company_field_enabled, false)
    end

    def editable?
      new_record? || Order.complete.where('bill_address_id = ? OR ship_address_id = ?', id, id).none?
    end

    def can_be_deleted?
      shipments.empty? && Order.complete.where('bill_address_id = ? OR ship_address_id = ?', id, id).none?
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
        saved_changes.key?(:state_code) || saved_changes.key?(:country_code)
      )
    end

    def set_default_values
      self.firstname ||= customer_owner.first_name
      self.lastname ||= customer_owner.last_name
      self.phone ||= customer_owner.phone
    end

    # The ISO code is what the address stores; the association is kept in step
    # with it for the one release it still exists. Assigning +country+ directly
    # is equally supported — whichever half was set fills in the other.
    def normalize_country
      submitted_iso = self[:country_code].presence
      return if submitted_iso.blank?

      resolved = Spree::Country.by_iso(submitted_iso)
      # Alpha-3 codes arrive here too; the column stores alpha-2. An
      # unrecognised code is left in place — the presence validation on
      # +country+ reports it.
      self[:country_code] = resolved.iso if resolved
    end

    # Resolves the subdivision code from whichever handle the caller supplied:
    # +state_code+ (which may be a retired code), or a +state_name+ that names
    # a real subdivision of this country. A name matching nothing is left
    # alone — countries without subdivisions keep it as free text, and
    # +state_validate+ decides whether that is acceptable.
    def normalize_state
      return if country_code.blank?

      submitted_abbr = self[:state_code].presence

      if submitted_abbr.present?
        resolved = Spree::IsoData.subdivision_code(country_code, submitted_abbr)

        # A code that means nothing in this country is stale — it came from the
        # country the address just moved off — so drop it and let the other
        # handles (a state_name, or nothing) decide.
        self[:state_code] = resolved
        return if resolved
      end

      return if state_name.blank?

      matched = Spree::IsoData.subdivision_code(country_code, state_name)
      return if matched.blank?

      self[:state_code] = matched
      self.state_name = nil
    end

    def clear_state
      self[:state_code] = nil
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
      customer = customer_owner
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

      if state_code.present?
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
      return if country.blank? || country_code.blank? || !require_zipcode? || zipcode.blank?
      return unless ::ValidatesZipcode::CldrRegexpCollection::ZIPCODES_REGEX.keys.include?(country_code.upcase.to_sym)

      formatted_zip = ::ValidatesZipcode::Formatter.new(
        zipcode: zipcode.to_s.strip,
        country_alpha2: country_code.upcase
      ).format

      errors.add(:zipcode, :invalid) unless ::ValidatesZipcode.valid?(formatted_zip, country_code.upcase)
    end

    def assign_new_default_address_to_user
      customer = customer_owner
      return unless customer

      customer.reload
      return if customer.bill_address != self && customer.ship_address != self

      last_address = assign_new_default_address_to_user_scope.find { |address| address.id != id && address.valid? }

      customer.bill_address = last_address if customer.bill_address == self
      customer.ship_address = last_address if customer.ship_address == self
      customer.save!
    end

    def assign_new_default_address_to_user_scope
      customer_owner.addresses.not_quick_checkout.reorder(created_at: :desc)
    end

    def unassign_from_incomplete_orders
      orders = Spree::Order.incomplete.where(customer_id: owner_id)
      orders.where(ship_address_id: id).update_all(ship_address_id: nil, updated_at: Time.current)
      orders.where(bill_address_id: id).update_all(bill_address_id: nil, updated_at: Time.current)
    end
  end
end
