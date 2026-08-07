module Spree
  class DeliveryZoneMember < Spree.base_class
    has_prefix_id :dzm

    MEMBER_TYPES = %w[country state postal_code].freeze

    # ISO codes of countries with numeric postal formats, where lexicographic
    # ranges over normalized codes are meaningful. Prefix members are allowed
    # for every country; range members only for these. Extend via
    # `Spree::DeliveryZoneMember.range_capable_country_isos += %w[XY]`.
    class_attribute :range_capable_country_isos, default: %w[
      AR AT AU BD BE BG BR CH CN CZ DE DK DZ EE EG ES FI FR GR HR HU ID IL IN
      IS IT JP KR LK LT LU MA MX MY NO NZ PH PK PL PT RO RS RU SA SE SG SI SK
      TH TN TR TW UA US UY VN ZA
    ].freeze

    belongs_to :delivery_zone, class_name: 'Spree::DeliveryZone', inverse_of: :members
    belongs_to :country, class_name: 'Spree::Country', optional: true
    belongs_to :state, class_name: 'Spree::State', optional: true

    normalizes :postal_code_prefix, :postal_code_from, :postal_code_to,
               with: ->(value) { Spree::Address.normalize_zipcode(value).presence }

    before_validation :normalize_iso_codes

    validates :member_type, presence: true, inclusion: { in: MEMBER_TYPES }
    validates :country_iso, presence: true, if: -> { member_type.in?(MEMBER_TYPES) }
    validates :state_abbr, presence: true, if: -> { member_type == 'state' }
    validate :postal_definition, if: -> { member_type == 'postal_code' }

    # @param address [Spree::Address]
    # @return [Boolean] whether the address falls inside this member
    #
    # A state member compares the country too: a subdivision code is only
    # unique within its country, so "CA" alone would match California and
    # several other places.
    def match?(address)
      case member_type
      when 'country' then same_country?(address)
      when 'state' then same_country?(address) && address.state_abbr.present? && address.state_abbr == state_abbr
      when 'postal_code' then same_country?(address) && postal_match?(address.normalized_zipcode)
      else false
      end
    end

    # @return [Boolean] whether this member defines a from/to range (vs a prefix)
    def postal_range?
      postal_code_from.present? || postal_code_to.present?
    end

    private

    def same_country?(address)
      country_iso.present? && address.country_iso == country_iso
    end

    # Members can still be built from country/state records, so the codes are
    # filled from them until those associations go in 6.1. A state supplies its
    # country as well — see +match?+.
    def normalize_iso_codes
      self.country_iso = country.iso if country_iso.blank? && country.present?

      return if state.blank?

      self.state_abbr = state.abbr if state_abbr.blank?
      self.country_iso = state.country&.iso if country_iso.blank?
    end

    # Stored values are normalized on assignment (see +normalizes+ above), so
    # matching compares normalized against normalized.
    def postal_match?(zipcode)
      return false if zipcode.blank?

      if postal_code_prefix.present?
        zipcode.start_with?(postal_code_prefix)
      else
        zipcode >= postal_code_from && zipcode <= postal_code_to
      end
    end

    def postal_definition
      if postal_code_prefix.present?
        errors.add(:postal_code_prefix, Spree.t('errors.messages.delivery_zone_prefix_and_range_exclusive')) if postal_range?
        return
      end

      if postal_code_from.blank? || postal_code_to.blank?
        errors.add(:base, Spree.t('errors.messages.delivery_zone_postal_definition_required'))
        return
      end

      unless country_iso.present? && range_capable_country_isos.include?(country_iso)
        errors.add(:base, Spree.t('errors.messages.delivery_zone_range_not_supported'))
        return
      end

      errors.add(:postal_code_to, Spree.t('errors.messages.delivery_zone_range_inverted')) if postal_code_to < postal_code_from
    end
  end
end
