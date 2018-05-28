module Spree
  class Address < Spree::Base
    require 'twitter_cldr'

    NO_ZIPCODE_ISO_CODES ||= [
      'AO', 'AG', 'AW', 'BS', 'BZ', 'BJ', 'BM', 'BO', 'BW', 'BF', 'BI', 'CM', 'CF', 'KM', 'CG',
      'CD', 'CK', 'CUW', 'CI', 'DJ', 'DM', 'GQ', 'ER', 'FJ', 'TF', 'GAB', 'GM', 'GH', 'GD', 'GN',
      'GY', 'HK', 'IE', 'KI', 'KP', 'LY', 'MO', 'MW', 'ML', 'MR', 'NR', 'AN', 'NU', 'KP', 'PA',
      'QA', 'RW', 'KN', 'LC', 'ST', 'SC', 'SL', 'SB', 'SO', 'SR', 'SY', 'TZ', 'TL', 'TK', 'TG',
      'TO', 'TV', 'UG', 'AE', 'VU', 'YE', 'ZW'
    ].freeze

    # we're not freezing this on purpose so developers can extend and manage
    # those attributes depending of the logic of their applications
    EXCLUDED_KEYS_FOR_COMPARISION = %w(id updated_at created_at)

    belongs_to :country, class_name: 'Spree::Country'
    belongs_to :state, class_name: 'Spree::State', optional: true

    has_many :shipments, inverse_of: :address

    before_validation :clear_invalid_state_entities, if: -> { country.present? }, on: :update

    with_options presence: true do
      validates :firstname, :lastname, :address1, :city, :country
      validates :zipcode, if: :require_zipcode?
      validates :phone, if: :require_phone?
    end

    validate :state_validate, :postal_code_validate

    alias_attribute :first_name, :firstname
    alias_attribute :last_name, :lastname

    self.whitelisted_ransackable_attributes = %w[firstname lastname company]

    def self.build_default
      new(country: Spree::Country.default)
    end

    def self.default(user = nil, kind = 'bill')
      if user && user_address = user.public_send(:"#{kind}_address")
        user_address.clone
      else
        build_default
      end
    end

    def full_name
      "#{firstname} #{lastname}".strip
    end

    def state_text
      state.try(:abbr) || state.try(:name) || state_name
    end

    def same_as?(other)
      return false if other.nil?
      attributes.except(*EXCLUDED_KEYS_FOR_COMPARISION) == other.attributes.except(*EXCLUDED_KEYS_FOR_COMPARISION)
    end

    alias same_as same_as?

    def to_s
      "#{full_name}: #{address1}"
    end

    def clone
      self.class.new(attributes.except('id', 'updated_at', 'created_at'))
    end

    def ==(other_address)
      self_attrs = attributes
      other_attrs = other_address.respond_to?(:attributes) ? other_address.attributes : {}

      [self_attrs, other_attrs].each { |attrs| attrs.except!('id', 'created_at', 'updated_at') }

      self_attrs == other_attrs
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
      Spree::Config[:address_requires_phone]
    end

    def require_zipcode?
      country ? country.zipcode_required? : true
    end

    private

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
      if state_name.present?
        if country.states.present?
          states = country.states.find_all_by_name_or_abbr(state_name)

          if states.size == 1
            self.state = states.first
            clear_state_name
          else
            errors.add(:state, :invalid)
          end
        end
      end

      # ensure at least one state field is populated
      errors.add :state, :blank if state.blank? && state_name.blank?
    end

    def postal_code_validate
      return if country.blank? || country.iso.blank? || !require_zipcode?
      return unless TwitterCldr::Shared::PostalCodes.territories.include?(country.iso.downcase.to_sym)

      postal_code = TwitterCldr::Shared::PostalCodes.for_territory(country.iso)
      errors.add(:zipcode, :invalid) unless postal_code.valid?(zipcode.to_s.strip)
    end
  end
end
