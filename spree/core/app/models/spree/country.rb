module Spree
  # A country, identified by its ISO 3166-1 alpha-2 code.
  #
  # Countries are reference data, not records: they are supplied by the
  # +countries+ gem through {Spree::IsoData} and are the same for every store.
  # Nothing stores a country id — addresses, delivery zones, markets and stock
  # locations all name a country by its ISO code.
  #
  # Being a plain object rather than an ActiveRecord model, this has no
  # +.where+, +.find+ or associations. Use {.by_iso} to look one up and
  # {.all} to enumerate.
  class Country
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :iso, :string
    attribute :iso3, :string
    attribute :numcode, :integer

    class << self
      # @return [Array<Spree::Country>] every country a store can sell to
      def all
        @all ||= Spree::IsoData.countries.map { |data| from_iso3166(data) }.freeze
      end

      # @param code [String] alpha-2 or alpha-3 code, in any case
      # @return [Spree::Country, nil]
      def by_iso(code)
        data = Spree::IsoData.country(code)
        data && from_iso3166(data)
      end

      # @param code [String] alpha-2 or alpha-3 code, in any case
      # @return [Spree::Country]
      # @raise [ActiveRecord::RecordNotFound] when no country has that code
      def find_by_iso!(code)
        by_iso(code) || raise(ActiveRecord::RecordNotFound, "Couldn't find Spree::Country with iso #{code.inspect}")
      end

      # @param iso [String]
      # @return [String] the country's flag as regional indicator characters
      def iso_to_emoji_flag(iso)
        iso.to_s.upcase.chars.map { |char| (char.ord + 127_397).chr(Encoding::UTF_8) }.join
      end

      # Drops the memoized list. Only needed when the gem's locale
      # configuration changes after boot, which in practice means specs.
      # @return [void]
      def reset!
        @all = nil
      end

      private

      def from_iso3166(data)
        new(iso: data.alpha2, iso3: data.alpha3, numcode: data.number)
      end
    end

    # @return [String] localized name, e.g. "Germany" or "Deutschland"
    def name
      localized_name
    end

    # The ISO's own uppercase name, kept for the API field of the same name.
    # @return [String]
    def iso_name
      (iso3166_country&.iso_short_name || iso.to_s).upcase
    end

    # @return [Array<Spree::State>] the country's subdivisions, ordered by name
    # Not memoized: .all hands out process-lifetime instances, and the names
    # are localized — caching here would pin one request's locale onto every
    # later one. IsoData holds the per-locale cache this reads from.
    def states
      Spree::IsoData.subdivisions(iso).map do |abbr, subdivision_name|
        Spree::State.new(abbr: abbr, name: subdivision_name, country_code: iso)
      end.freeze
    end

    # @return [Boolean] whether an address here must name a subdivision
    def states_required
      Spree::Address::STATES_REQUIRED.include?(iso.to_s.upcase)
    end
    alias states_required? states_required

    # @return [Boolean] whether an address here must carry a postal code
    def zipcode_required
      !Spree::Address::NO_ZIPCODE_ISO_CODES.include?(iso.to_s.upcase)
    end
    alias zipcode_required? zipcode_required

    # @param store [Spree::Store, nil]
    # @return [Boolean] whether this is the store's default country
    def default?(store = nil)
      store ||= Spree::Store.default
      self == store&.default_country
    end

    # Looks up the Market covering this country for the current Store.
    # @return [Spree::Market, nil]
    # Not memoized, for the same reason as #states: these instances are shared
    # across the process, so caching a market here would serve one store's
    # market to every other store — and would never notice a market edit.
    def current_market
      Spree::Current.store&.market_for_country(self)
    end

    # Display name for +locale+, falling back to the ISO's own name when the
    # gem carries no translation for it.
    # @param locale [Symbol, String]
    # @return [String]
    def localized_name(locale: I18n.locale)
      data = iso3166_country
      return iso.to_s unless data

      base_locale = locale.to_s.downcase.tr('_', '-').split('-').first
      (data.translation(base_locale) || data.iso_short_name).presence || iso.to_s
    end

    # Flag emoji + localized name, for select options.
    # @param locale [Symbol, String]
    # @return [String]
    def option_label(locale: I18n.locale)
      "#{self.class.iso_to_emoji_flag(iso)} #{localized_name(locale: locale)}"
    end

    # @return [String, nil] e.g. 'USD'
    def default_currency
      iso3166_country&.currency_code
    end

    # @return [String, nil] e.g. 'en'
    def default_locale
      iso3166_country&.languages&.first
    end

    # Countries are equal when they name the same place, so they can be
    # compared, deduplicated and used as hash keys.
    def ==(other)
      other.is_a?(Spree::Country) && other.iso == iso
    end
    alias eql? ==

    def hash
      iso.hash
    end

    def <=>(other)
      return nil unless other.is_a?(Spree::Country)

      name <=> other.name
    end

    def to_s
      name
    end

    private

    def iso3166_country
      @iso3166_country ||= ISO3166::Country[iso.to_s.upcase]
    end
  end
end
