# Loaded here rather than with core's other gems: valvat's entry point pulls in
# its VIES lookup client, and with it REXML and net/http — around 90ms and a
# hundred files, on every boot, for a SOAP service this validator never calls.
# Deferring it to the first EU VAT check keeps that off installs that never do
# one, and off every rake task and console.
require 'valvat'

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
        # for and syntax alone decides Czechia, Latvia and Slovakia. That
        # fallback is the point: refusing every number we cannot fully verify
        # would turn away real customers in those three to catch a typo, and
        # turning away a paying business is the more expensive mistake.
        #
        # valvat recognises the 27 member states and Great Britain, and nothing
        # else — so excluding Great Britain is the whole of the area check.
        # Northern Ireland kept EU VAT treatment for goods under the Windsor
        # Framework and is the reason that exclusion reads on the prefix: its
        # +XI+ numbers report +GB+ as their country.
        #
        # @param value [String] already normalized (whitespace stripped, upcased)
        # @return [Boolean]
        def self.valid_format?(value)
          vat = Valvat.new(value.to_s)
          return false if vat.iso_country_code == 'GB' && vat.vat_country_code != 'XI'

          Valvat::Checksum.validate(vat)
        end
      end
    end
  end
end
