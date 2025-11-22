module Spree
  class Address < Spree.base_class
    require 'validates_zipcode'

    include Spree::Metafields
    include Spree::Metadata
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

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
    EXCLUDED_KEYS_FOR_COMPARISON = %w(id updated_at created_at deleted_at label user_id public_metadata private_metadata)
    FIELDS_TO_NORMALIZE = %w(firstname lastname phone alternative_phone company address1 address2 city zipcode)

    if defined?(Spree::Security::Addresses)
      include Spree::Security::Addresses
    end

    scope :not_deleted, -> { where(deleted_at: nil) }

    scope :by_state_name_or_abbr, lambda { |state_name|
      joins(:state).merge(Spree::State.where(name: state_name).or(Spree::State.where(abbr: state_name)))
    }

    scope :not_quick_checkout, -> { where(quick_checkout: false) }

    belongs_to :country, class_name: 'Spree::Country'
    belongs_to :state, class_name: 'Spree::State', optional: true
    # we need a safe operator here as Address is added to metafield_enabled_resources in Engine
    belongs_to :user, class_name: Spree.user_class&.name, optional: true, touch: true

    has_many :shipments, inverse_of: :address

    after_initialize :set_default_values, if: -> { new_record? && user.present? }

    before_validation :clear_invalid_state_entities, if: -> { country.present? }, on: :update
    before_validation :remove_emoji_and_normalize

    after_create :set_user_attributes, if: -> { user.present? }

    after_commit :async_geocode

    with_options presence: true do
      validates :firstname, :lastname, if: :require_name?
      validates :address1, if: :require_street?
      validates :city, :country
      validates :zipcode, if: :require_zipcode?
      validates :phone, if: :require_phone?
    end

    validate :state_validate, :postal_code_validate
    validate :address_validators, on: [:create, :update]

    validates :label, uniqueness: { conditions: -> { where(deleted_at: nil) },
                                    scope: :user_id,
                                    case_sensitive: false,
                                    allow_blank: true,
                                    allow_nil: true }

    def address_validators
      Spree.validators.addresses.each do |validator|
        validates_with validator
      end
    end

    delegate :name, :iso3, :iso, :iso_name, to: :country, prefix: true
    delegate :abbr, to: :state, prefix: true, allow_nil: true

    alias_attribute :postal_code, :zipcode

    self.whitelisted_ransackable_attributes = ADDRESS_FIELDS
    self.whitelisted_ransackable_associations = %w[country state user]

    def self.required_fields
      Spree::Address.validators.map do |v|
        v.is_a?(ActiveModel::Validations::PresenceValidator) ? v.attributes : []
      end.flatten
    end

    def user_default_billing?
      user.present? && id == user.bill_address_id
    end

    def user_default_shipping?
      user.present? && id == user.ship_address_id
    end

    def first_name
      firstname
    end

    def first_name=(value)
      self.firstname = value
    end

    def last_name
      lastname
    end

    def last_name=(value)
      self.lastname = value
    end

    def full_name
      "#{firstname} #{lastname}".strip
    end

    def state_text
      state.try(:abbr) || state.try(:name) || state_name
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

    def empty?
      attributes.except('id', 'created_at', 'updated_at', 'country_id').all? { |_, v| v.nil? }
    end

    # Generates an ActiveMerchant compatible address hash
    def active_merchant_hash
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

    def require_phone?
      # We want to collect phone number for quick checkout but not to validate it
      # as it's not available before payment by browser.
      !quick_checkout && Spree::Config[:address_requires_phone]
    end

    def require_zipcode?
      !quick_checkout && (country ? country.zipcode_required? : true)
    end

    def require_name?
      !quick_checkout
    end

    def require_company?
      false
    end

    def require_street?
      !quick_checkout
    end

    def show_company_address_field?
      Spree::Store.current.prefers_company_field_enabled?
    end

    def editable?
      new_record? || Order.complete.where('bill_address_id = ? OR ship_address_id = ?', id, id).none?
    end

    def can_be_deleted?
      shipments.empty? && Order.complete.where('bill_address_id = ? OR ship_address_id = ?', id, id).none?
    end

    def check
      attrs = attributes.except('id', 'updated_at', 'created_at')
      the_same_address = user&.addresses&.find_by(attrs)
      the_same_address || self
    end

    def destroy
      assign_new_default_address_to_user

      if can_be_deleted?
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

    def should_geocode?
      Spree::Config[:geocode_addresses] && (
        saved_changes.key?(:address1) || saved_changes.key?(:city) || saved_changes.key?(:state_id) || saved_changes.key?(:country_id)
      )
    end

    def set_default_values
      self.firstname ||= user.first_name
      self.lastname ||= user.last_name
      self.phone ||= user.phone
    end

    def clear_state
      self.state = nil
    end

    def clear_state_name
      self.state_name = nil
    end

    def clear_invalid_state_entities
      if state.present? && (state.country != country)
        clear_state
      elsif state_name.present? && !country.states_required? && country.states.empty?
        clear_state_name
      end
    end

    def remove_emoji_and_normalize
      attributes_to_normalize = attributes.slice(*FIELDS_TO_NORMALIZE)
      normalized_attributes = attributes_to_normalize.compact_blank.deep_transform_values do |value|
        NormalizeString.remove_emoji_and_normalize(value.to_s).strip
      end

      normalized_attributes.transform_keys! { |key| key.gsub('original_', '') } if defined?(Spree::Security::Addresses)

      assign_attributes(normalized_attributes)
    end

    def set_user_attributes
      if user.name.blank?
        user.first_name = firstname
        user.last_name = lastname
      end
      user.phone = user.phone.presence || phone.presence

      user.save! if user.changed?
    end

    def state_validate
      # Skip state validation without country (also required)
      # or when disabled by preference
      return if country.blank? || !Spree::Config[:address_requires_state]
      return unless country.states_required

      # ensure associated state belongs to country
      if state.present?
        if state.country == country
          clear_state_name # not required as we have a valid state and country combo
        elsif state_name.present?
          clear_state
        else
          errors.add(:state, :invalid)
        end
      end

      # ensure state_name belongs to country without states, or that it matches a predefined state name/abbr
      if state_name.present? && country.states.present?
        states = country.states.find_all_by_name_or_abbr(state_name)

        if states.size == 1
          self.state = states.first
          clear_state_name
        else
          errors.add(:state, :invalid)
        end
      end

      # ensure at least one state field is populated
      errors.add :state, :blank if state.blank? && state_name.blank?
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
      return unless user

      user.reload
      return if user.bill_address != self && user.ship_address != self

      last_address = assign_new_default_address_to_user_scope.find { |address| address.id != id && address.valid? }

      user.bill_address = last_address if user.bill_address == self
      user.ship_address = last_address if user.ship_address == self
      user.save!
    end

    def assign_new_default_address_to_user_scope
      user.addresses.not_quick_checkout.reorder(created_at: :desc)
    end
  end
end
