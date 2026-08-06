module Spree
  module TaxIdentifiers
    class ValidationError < StandardError; end

    # The only writer of the validation columns. Writes with +update_columns+ so
    # recording a verdict cannot re-trigger the callback that asked for it.
    class Validate
      prepend Spree::ServiceModule::Base

      # @param tax_identifier [Spree::TaxIdentifier]
      # @return [Spree::TaxIdentifier]
      def call(tax_identifier:)
        validator = Spree.tax_identifier_validators[tax_identifier.kind]

        # Narrow race: the validator was deregistered between enqueue and run.
        return persist(tax_identifier, unsupported_result) if validator.blank?

        result = validator.to_s.constantize.new.call(tax_identifier: tax_identifier)
        persist(tax_identifier, result)
      rescue StandardError => error
        # A number nobody could check is not a number known to be wrong, so it
        # is recorded as unanswered rather than rejected — and recorded rather
        # than left on the `pending` the enqueue stamped. Reported rather than
        # raised, as a failed geocode is.
        Rails.error.report(
          ValidationError.new("Cannot validate tax identifier ID: #{tax_identifier.id} (#{error.message})"),
          handled: false,
          context: { tax_identifier_id: tax_identifier.id, kind: tax_identifier.kind },
          source: 'spree.core'
        )
        persist(tax_identifier, unavailable_result(error.message))
        failure(tax_identifier, error.message)
      end

      private

      def persist(tax_identifier, result)
        return failure(tax_identifier, result.errors.full_messages.to_sentence) unless result.valid?

        tax_identifier.update_columns(result.to_columns.merge(updated_at: Time.current))
        success(tax_identifier)
      end

      def unsupported_result
        Spree::TaxIdentifiers::ValidationResult.new(status: 'unsupported', checked_at: Time.current)
      end

      def unavailable_result(message)
        Spree::TaxIdentifiers::ValidationResult.new(status: 'unavailable', message: message, checked_at: Time.current)
      end
    end
  end
end
