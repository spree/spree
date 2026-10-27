module SpreeVies
  # Prepended to core's ValidateJob, so every check of an EU VAT number — after
  # it changes, from the admin, a retry or re-validation — is skipped while a
  # check of the same number is already running. That check will record the
  # answer; asking VIES twice only spends its rate limit.
  #
  # Keyed on the number as well as the row: a number changed mid-check must
  # still be asked about, since the running check will not record an answer for
  # a number the row no longer holds. Needs a cache store shared between
  # processes to hold across workers.
  module CheckGuard
    IN_FLIGHT_FOR = 2.minutes

    def perform(tax_identifier_id)
      tax_identifier = Spree::TaxIdentifier.find_by(id: tax_identifier_id)
      return super unless tax_identifier&.kind == 'eu_vat'

      key = "spree_vies/checking/#{tax_identifier.id}/#{tax_identifier.value}"
      return unless Rails.cache.write(key, true, unless_exist: true, expires_in: IN_FLIGHT_FOR)

      begin
        super
      ensure
        Rails.cache.delete(key)
      end
    end
  end
end
