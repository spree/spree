module SpreeVies
  # The check the gem queues itself — retries and re-validation — which must not
  # pile onto a check of the same number already running. Needs a cache store
  # shared between processes for that guard to hold across workers.
  class ValidateJob < Spree::TaxIdentifiers::ValidateJob
    IN_FLIGHT_FOR = 2.minutes

    def perform(tax_identifier_id)
      key = "spree_vies/checking/#{tax_identifier_id}"
      return unless Rails.cache.write(key, true, unless_exist: true, expires_in: IN_FLIGHT_FOR)

      begin
        super
      ensure
        Rails.cache.delete(key)
      end
    end
  end
end
