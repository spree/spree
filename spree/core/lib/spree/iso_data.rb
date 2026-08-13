module Spree
  # Reference data for countries and their subdivisions, sourced from the
  # +countries+ gem (ISO 3166). Backs {Spree::Country} and {Spree::State},
  # which are value objects rather than database records.
  #
  # The gem's raw subdivision list is not usable as-is at checkout, so this
  # module curates it in three ways:
  #
  # * {SUBDIVISION_TYPES} keeps only the subdivision kinds a customer would
  #   recognise as a "state" for that country.
  # * {SUBDIVISION_ADDITIONS} restores entries the gem omits but real addresses
  #   still use — US military codes, and Italian provinces abolished in 2016.
  # * {SUBDIVISION_ALIASES} maps codes that ISO has since renamed onto their
  #   successors, so an address stored years ago still resolves.
  #
  # Without the last two, upgrading would invalidate addresses that were
  # perfectly valid when they were entered.
  module IsoData
    # Territories, uninhabited islands and Antarctica — never orderable.
    EXCLUDED_COUNTRIES = %w[AQ AX GS UM HM IO EH BV TF].freeze

    # Subdivision types to keep, per country. A country absent from this hash
    # keeps every type the gem lists for it.
    #
    # The US would otherwise carry six outlying areas (Guam, Puerto Rico and
    # friends) alongside the 50 states and DC; China would carry Hong Kong and
    # Macao, which Spree treats as countries in their own right.
    SUBDIVISION_TYPES = {
      'US' => %w[state district],
      'CN' => %w[province municipality autonomous_region]
    }.freeze

    # Codes dropped after the type filter. Taiwan is an autonomous region in the
    # gem's Chinese subdivision list and a country everywhere else.
    SUBDIVISION_EXCLUSIONS = { 'CN' => %w[TW] }.freeze

    # Subdivisions the gem does not list but addresses legitimately use.
    #
    # The US military codes are how APO/FPO mail is addressed and every US
    # checkout accepts them. The Sardinian provinces were abolished in 2016
    # with no successor, so an address from before then has nowhere else to go.
    SUBDIVISION_ADDITIONS = {
      'US' => {
        'AA' => 'Armed Forces Americas',
        'AE' => 'Armed Forces Europe',
        'AP' => 'Armed Forces Pacific'
      },
      'IT' => {
        'CI' => 'Carbonia-Iglesias',
        'OG' => 'Ogliastra',
        'OT' => 'Olbia-Tempio',
        'VS' => 'Medio Campidano'
      }
    }.freeze

    # Retired ISO codes mapped to their current equivalent. Reading an address
    # written under the old code still finds the right subdivision; writing
    # always stores the successor.
    SUBDIVISION_ALIASES = {
      'IN' => {
        'CT' => 'CG',  # Chhattisgarh
        'OR' => 'OD',  # Odisha
        'TG' => 'TS',  # Telangana
        'UT' => 'UK',  # Uttarakhand
        'DD' => 'DH',  # Daman and Diu, merged in 2020
        'DN' => 'DH'   # Dadra and Nagar Haveli, merged in 2020
      },
      'IT' => { 'AO' => '23' }, # Valle d'Aosta, now coded as a region
      'ZA' => {
        'GT' => 'GP',  # Gauteng
        'NL' => 'ZN'   # KwaZulu-Natal
      }
    }.freeze

    class << self
      # Every orderable country, memoized for the life of the process.
      # @return [Array<ISO3166::Country>]
      def countries
        @countries ||= ISO3166::Country.all.
                       reject { |country| EXCLUDED_COUNTRIES.include?(country.alpha2) }.
                       freeze
      end

      # @param code [String] alpha-2 or alpha-3 code, any case
      # @return [ISO3166::Country, nil]
      def country(code)
        return nil if code.blank?

        code = code.to_s.strip.upcase
        found = ISO3166::Country[code] || ISO3166::Country.find_country_by_alpha3(code)
        return nil if found.nil? || EXCLUDED_COUNTRIES.include?(found.alpha2)

        found
      end

      # The curated subdivisions for a country, as +{ code => name }+, ordered
      # by name.
      #
      # @param iso [String] alpha-2 country code
      # @return [Hash{String => String}]
      # Keyed by locale as well as country: the names are localized, and this
      # cache outlives a request, so keying on the country alone would serve
      # whichever locale happened to warm it to everyone else.
      def subdivisions(iso)
        iso = iso.to_s.upcase
        @subdivisions ||= {}
        @subdivisions[[I18n.locale, iso]] ||= build_subdivisions(iso).freeze
      end

      # Resolves whatever handle a caller has — a current code, a retired one,
      # or a subdivision name — to a current code.
      #
      # @param iso [String] alpha-2 country code
      # @param value [String] code or name
      # @return [String, nil] the current subdivision code
      def subdivision_code(iso, value)
        return nil if value.blank?

        iso = iso.to_s.upcase
        candidate = value.to_s.strip
        available = subdivisions(iso)

        upcased = candidate.upcase
        return upcased if available.key?(upcased)

        aliased = SUBDIVISION_ALIASES.dig(iso, upcased)
        return aliased if aliased && available.key?(aliased)

        by_name = available.find { |_code, name| name.casecmp?(candidate) }
        return by_name.first if by_name

        # Falls back to the gem, which also matches translated names.
        country(iso)&.find_subdivision_by_name(candidate)&.code.presence
      end

      # @param iso [String] alpha-2 country code
      # @param code [String] subdivision code
      # @return [String, nil] the subdivision's name
      def subdivision_name(iso, code)
        subdivisions(iso)[code.to_s.upcase]
      end

      # Drops memoized data. Only needed when locale configuration changes
      # after boot, which in practice means specs.
      # @return [void]
      def reset!
        @countries = nil
        @subdivisions = nil
      end

      private

      def build_subdivisions(iso)
        source = country(iso)
        return {} if source.nil?

        types = SUBDIVISION_TYPES[iso]
        selected = types ? source.subdivisions_of_types(types) : source.subdivisions
        excluded = SUBDIVISION_EXCLUSIONS.fetch(iso, [])

        entries = selected.
                  reject { |code, _| excluded.include?(code) }.
                  map { |code, subdivision| [code, subdivision_display_name(subdivision)] }

        entries.concat(SUBDIVISION_ADDITIONS.fetch(iso, {}).to_a)
        entries.sort_by { |_code, name| name.to_s }.to_h
      end

      # Under a non-English locale a subdivision is named by its translation,
      # when the gem has one for the locales it was configured with.
      #
      # English deliberately reads the canonical +name+ rather than the +en+
      # translation: the two disagree in places (the gem translates DC as
      # "Washington DC", where the canonical name is "District of Columbia"),
      # and the canonical spelling is the one Spree has always stored.
      #
      # Note the translation keys are symbols here, unlike +Country#translation+,
      # which takes a string.
      def subdivision_display_name(subdivision)
        locale = I18n.locale.to_s.downcase
        return subdivision.name if locale.start_with?('en')

        translations = subdivision.translations || {}
        translations[locale.to_sym].presence || subdivision.name
      end
    end
  end
end
