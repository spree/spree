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
        # What this run is answering about. The buyer can change the number while
        # a check is in flight, and a verdict about the old one must not be
        # written over the new one — see #persist.
        @checked = tax_identifier.slice(:kind, :value)

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

      # Re-read before writing. A slower check for a number the buyer has since
      # replaced would otherwise stamp its verdict onto the new one — reporting
      # a registration as verified when nothing has verified it, which is what
      # decides reverse charge. The row is already `pending` from the write that
      # replaced it, and its own check is on the way.
      def persist(tax_identifier, result)
        return failure(tax_identifier, result.errors.full_messages.to_sentence) unless result.valid?

        current = tax_identifier.class.find_by(id: tax_identifier.id)
        return success(tax_identifier) if current.nil?
        return success(tax_identifier) if current.slice(:kind, :value) != @checked

        current.update_columns(result.to_columns.merge(updated_at: Time.current))
        success(current)
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
