module Spree
  module TaxIdentifiers
    class ValidateJob < BaseJob
      queue_as Spree.queues.tax_identifiers

      def perform(tax_identifier_id)
        tax_identifier = Spree::TaxIdentifier.find_by(id: tax_identifier_id)
        return if tax_identifier.nil?

        Spree::TaxIdentifiers::Validate.call(tax_identifier: tax_identifier)
      end
    end
  end
end
