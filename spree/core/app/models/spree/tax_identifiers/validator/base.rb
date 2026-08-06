module Spree
  module TaxIdentifiers
    module Validator
      # Contract for checking a buyer's tax registration. Registered per kind in
      # {Spree.tax_identifier_validators}, because whether a number is
      # well-formed and whether it is really registered are questions for the
      # jurisdiction that issued it — not for the market's tax engine.
      #
      # Two halves, deliberately split by cost: the format check is synchronous,
      # offline and cheap enough to run on every save; the registry check makes
      # a network call and runs in a job.
      class Base
        # Whether the value looks like a number of this kind. Called on save, so
        # it must not touch the network.
        #
        # Permissive by default: a validator that only knows how to talk to a
        # registry accepts anything core allowed through.
        #
        # @param value [String] already normalized (whitespace stripped, upcased)
        # @return [Boolean]
        def self.valid_format?(_value)
          true
        end

        # Asks the registry whether the number is registered. Runs in
        # {Spree::TaxIdentifiers::ValidateJob}.
        #
        # A registry that cannot answer must return an +unavailable+ result
        # rather than raise: the number stays usable and the platform records
        # that nobody could answer.
        #
        # @param tax_identifier [Spree::TaxIdentifier] carries the kind, the
        #   value and its owner — reach the store through the owner when the
        #   registry needs credentials
        # @return [Spree::TaxIdentifiers::ValidationResult]
        def call(tax_identifier:)
          raise NotImplementedError, "Please implement 'call' in your tax ID validator: #{self.class.name}"
        end
      end
    end
  end
end
