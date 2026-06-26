module Spree
  class Country < Spree.base_class
    self.whitelisted_ransackable_attributes = %w[iso iso3 iso_name name]

    has_many :addresses, dependent: :restrict_with_error
    has_many :states,
             -> { order name: :asc },
             inverse_of: :country,
             dependent: :destroy
    has_many :zone_members,
             -> { where(zoneable_type: 'Spree::Country') },
             class_name: 'Spree::ZoneMember',
             dependent: :destroy,
             foreign_key: :zoneable_id
    has_many :zones, through: :zone_members, class_name: 'Spree::Zone'
    has_many :market_countries, class_name: 'Spree::MarketCountry', dependent: :destroy
    has_many :markets, through: :market_countries, class_name: 'Spree::Market'

    validates :name, :iso_name, :iso, :iso3, presence: true, uniqueness: { case_sensitive: false, scope: spree_base_uniqueness_scope }

    def self.by_iso(iso)
      where(['LOWER(iso) = ?', iso.downcase]).or(where(['LOWER(iso3) = ?', iso.downcase])).take
    end

    def default?(store = nil)
      store ||= Spree::Store.default
      self == store.default_country
    end

    def self.to_tom_select_json
      pluck(:name, :id, :iso).map do |name, id, iso|
        {
          id: id,
          name: new(iso: iso, name: name).option_label
        }
      end.as_json
    end

    def self.iso_to_emoji_flag(iso)
      iso.upcase.chars.map { |c| (c.ord + 127397).chr(Encoding::UTF_8) }.join
    end

    # Lookups Market for Country for the current Store
    # @return [Spree::Market, nil]
    def current_market
      @current_market ||= Spree::Current.store&.market_for_country(self)
    end

    # Display name localized to +locale+ via the countries gem (CLDR), falling
    # back to the stored +name+ (or the ISO when there is no name) for an
    # unknown ISO or missing translation.
    # @param locale [Symbol, String]
    # @return [String]
    def localized_name(locale: I18n.locale)
      fallback = name.presence || iso.to_s
      data = ISO3166::Country[iso.to_s.upcase]
      return fallback unless data

      base_locale = locale.to_s.downcase.tr('_', '-').split('-').first
      (data.translation(base_locale) || data.translation(:en)).presence || fallback
    end

    # Flag emoji + localized name, for select options.
    # @param locale [Symbol, String]
    # @return [String]
    def option_label(locale: I18n.locale)
      "#{self.class.iso_to_emoji_flag(iso)} #{localized_name(locale: locale)}"
    end

    def <=>(other)
      name <=> other.name
    end

    def to_s
      name
    end

    # Returns the default currency code for this country (e.g., 'USD', 'EUR')
    # Uses the countries gem (ISO3166) for accurate currency data
    def default_currency
      iso3166_country&.currency_code
    end

    # Returns the default locale/language for this country (e.g., 'en', 'de')
    # Uses the countries gem (ISO3166) for accurate language data
    def default_locale
      iso3166_country&.languages&.first
    end

    private

    def iso3166_country
      @iso3166_country ||= ISO3166::Country.new(iso)
    end
  end
end
