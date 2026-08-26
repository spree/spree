module Spree
  module TestingSupport
    # Structurally valid EU VAT numbers for the :tax_identifier factory to cycle
    # through.
    #
    # Core format-checks +eu_vat+ out of the box, so a factory can no longer
    # invent numbers by counting upward: the check digit makes valid numbers
    # land at irregular intervals, and a made-up one is simply rejected. Same
    # problem as {CountryPool}, same answer — hand the factory real ones.
    #
    # These pass the checksum and nothing more. They identify no business, and
    # no registry has been asked about them.
    module VatNumberPool
      # German numbers, whose check digit is the most widely implemented of the
      # 25 valvat can verify — so a spec failure here means the validator
      # changed rather than the fixture rotting.
      NUMBERS = %w[
        DE100000008 DE100000016 DE100000024 DE100000032 DE100000049
        DE100000057 DE100000065 DE100000073 DE100000081 DE100000090
        DE100000104 DE100000112 DE100000129 DE100000137 DE100000145
        DE100000153 DE100000161 DE100000170 DE100000188 DE100000196
        DE100000207 DE100000215 DE100000223 DE100000231 DE100000240
        DE100000258 DE100000266 DE100000274 DE100000282 DE100000299
        DE100000303 DE100000311 DE100000320 DE100000338 DE100000346
        DE100000354 DE100000362 DE100000379 DE100000387 DE100000395
        DE100000400 DE100000418 DE100000426 DE100000434 DE100000442
        DE100000459 DE100000467 DE100000475 DE100000483 DE100000491
      ].freeze

      # Wraps, so a spec creating more than {NUMBERS} registrations for one
      # owner and kind would repeat a number and hit the uniqueness validation
      # instead of the failure it was written for. Nothing comes close today.
      #
      # @param index [Integer] any counter; wraps around the pool
      # @return [String] a checksum-valid EU VAT number
      def self.at(index)
        NUMBERS[index.to_i % NUMBERS.size]
      end
    end
  end
end
