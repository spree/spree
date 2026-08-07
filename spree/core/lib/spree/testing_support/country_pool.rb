module Spree
  module TestingSupport
    # Real ISO codes for the :country factory to cycle through.
    #
    # Country records only mean anything if their code is one the countries gem
    # knows — that is what resolves subdivisions, names and currencies — so the
    # factory can't invent codes the way it used to.
    #
    # US is excluded: it is the default store's country and specs asking for
    # "a different country" would otherwise collide with it.
    module CountryPool
      ISO_CODES = %w[
        PL DE FR GB IT ES NL BE SE NO DK FI PT AT CH IE GR CZ HU RO
        CA MX BR AR CL AU NZ JP CN IN ZA
      ].freeze

      # @param index [Integer] any counter; wraps around the pool
      # @return [String] a real alpha-2 code
      def self.iso_for(index)
        ISO_CODES[index.to_i % ISO_CODES.size]
      end

      # Codes whose subdivisions the gem knows, for state-bearing specs.
      # @return [Array<String>]
      def self.with_subdivisions
        @with_subdivisions ||= ISO_CODES.select { |iso| Spree::IsoData.subdivisions(iso).any? }
      end

      # A postal code the country actually accepts. Addresses are validated
      # against per-country formats, so a single hardcoded value cannot serve
      # every country the factory might pick.
      POSTAL_CODES = {
        'US' => '10118', 'CA' => 'K1A 0B1', 'GB' => 'SW1A 1AA', 'PL' => '00-001',
        'DE' => '10115', 'FR' => '75001', 'IT' => '00100', 'ES' => '28001',
        'NL' => '1011 AB', 'BE' => '1000', 'SE' => '111 20', 'NO' => '0010',
        'DK' => '1050', 'FI' => '00100', 'PT' => '1000-001', 'AT' => '1010',
        'CH' => '8001', 'IE' => 'D02 AF30', 'GR' => '104 31', 'CZ' => '110 00',
        'HU' => '1011', 'RO' => '010011', 'MX' => '01000', 'BR' => '01310-100',
        'AR' => 'C1002', 'CL' => '8320000', 'AU' => '2000', 'NZ' => '6011',
        'JP' => '100-0001', 'CN' => '100000', 'IN' => '110001', 'ZA' => '0001'
      }.freeze

      # @param iso [String, nil]
      # @return [String] a postal code valid for that country
      def self.postal_code_for(iso)
        POSTAL_CODES.fetch(iso.to_s.upcase, '10118')
      end
    end
  end
end
