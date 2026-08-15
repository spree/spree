module Spree
  # A subdivision of a country — a state, province, region or whatever that
  # country calls it — identified by its ISO 3166-2 code without the country
  # prefix ("CA", not "US-CA").
  #
  # Like {Spree::Country} this is reference data supplied by the +countries+
  # gem rather than a record. A code is only meaningful together with its
  # country, so every state carries +country_code+.
  class State
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :abbr, :string # the ISO 3166-2 code without the country prefix
    attribute :name, :string
    attribute :country_code, :string

    class << self
      # @param country_code [String]
      # @return [Array<Spree::State>] that country's subdivisions, by name
      def for_country(country_code)
        Spree::IsoData.subdivisions(country_code).map do |abbr, name|
          new(abbr: abbr, name: name, country_code: country_code)
        end
      end

      # Resolves a subdivision from a code or a name, including codes ISO has
      # since retired.
      #
      # @param country_code [String]
      # @param value [String] code or name
      # @return [Spree::State, nil]
      def resolve(country_code, value)
        code = Spree::IsoData.subdivision_code(country_code, value)
        return nil if code.blank?

        new(abbr: code, name: Spree::IsoData.subdivision_name(country_code, code), country_code: country_code)
      end

      # @param country_code [String]
      # @param name_or_abbr [String]
      # @return [Array<Spree::State>] the match, or empty when there is none
      def find_all_by_name_or_abbr(country_code, name_or_abbr)
        Array(resolve(country_code, name_or_abbr))
      end
    end

    alias_method :code, :abbr

    # @return [Spree::Country, nil]
    def country
      @country ||= Spree::Country.by_iso(country_code)
    end

    # States are equal when they name the same subdivision of the same
    # country — an abbreviation alone is not unique.
    def ==(other)
      other.is_a?(Spree::State) && other.abbr == abbr && other.country_code == country_code
    end
    alias eql? ==

    def hash
      [country_code, abbr].hash
    end

    def <=>(other)
      return nil unless other.is_a?(Spree::State)

      name.to_s <=> other.name.to_s
    end

    def to_s
      name
    end
  end
end
