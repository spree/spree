module Spree
  module TaxIdentifiers
    module Validator
      # The offline half of checking an EU VAT number, and only that half.
      #
      # Registered for +eu_vat+ out of the box, because a number's shape is
      # arithmetic rather than a service: the rules are published in the
      # directive, they do not change between installations, and checking them
      # costs nothing. This follows the same reasoning that puts postal codes on
      # +validates_zipcode+ and phone numbers on +phonelib+ — a merchant should
      # not have to install anything to be told that +DE123+ is not a VAT
      # number.
      #
      # What it deliberately does not do is ask VIES whether the number is
      # *registered*. That is a network call to a service which is regularly
      # slow or down, so it stays with the extension that wants it. Declaring
      # {checks_registry?} false is what keeps core from queueing a check
      # nobody here can answer; an extension covering the registry re-registers
      # +eu_vat+ and takes over both halves.
      #
      # A passing check is not a claim that the business exists — only that the
      # number is not a typo. Registration is what +verified+ means, and only a
      # registry can say it.
      class EuVat < Base
        # Member states by ISO code, which is what valvat reports for a number's
        # issuer. Not the VAT prefix: Greece issues +EL+ numbers while its ISO
        # code is +GR+, so matching prefixes against this list would refuse
        # every Greek registration.
        ISO_COUNTRY_CODES = Valvat::Utils::EU_MEMBER_STATES.freeze

        # Northern Ireland keeps EU VAT treatment for goods under the Windsor
        # Framework and issues +XI+ numbers. It has no ISO code of its own —
        # valvat reports +GB+ — so it is matched on the prefix instead.
        NORTHERN_IRELAND_PREFIX = 'XI'.freeze

        # No registry client here, so core never enqueues a check for a number
        # of this kind. Verdicts stay blank rather than reading +unavailable+,
        # which is the honest answer: nobody was asked.
        #
        # @return [Boolean]
        def self.checks_registry?
          false
        end

        # True when the number is well-formed for the member state that issued
        # it.
        #
        # Checksums are applied for the 24 member states valvat has an algorithm
        # for and syntax alone decides Czechia, Latvia and Slovakia, which is
        # what +Valvat::Checksum.validate+ already does. That fallback is the
        # point: refusing every number we cannot fully verify would turn away
        # real customers in those three to catch a typo, and turning away a
        # paying business is the more expensive mistake.
        #
        # @param value [String] already normalized (whitespace stripped, upcased)
        # @return [Boolean]
        def self.valid_format?(value)
          vat = Valvat.new(value.to_s)
          return false unless in_vat_area?(vat)

          Valvat::Checksum.validate(vat)
        end

        # @param vat [Valvat]
        # @return [Boolean]
        def self.in_vat_area?(vat)
          return true if vat.vat_country_code == NORTHERN_IRELAND_PREFIX

          ISO_COUNTRY_CODES.include?(vat.iso_country_code)
        end
        private_class_method :in_vat_area?
      end
    end
  end
end
