module SpreeKlaviyo
  # Imports a profile from a customer, or from an order, cart or order group.
  class SyncProfileJob < BaseJob
    # @param integration [Spree::Integrations::Klaviyo]
    # @param record [Spree::Customer, Spree::Order, Spree::Cart, Spree::OrderGroup]
    def perform(integration, record)
      use_database_ids = integration.preferred_use_database_ids_as_external_ids
      profile =
        if record.is_a?(Spree.customer_class)
          # Checked when the job runs: an erasure's own customer.updated, or an
          # older one still queued, must not write the tombstone over the profile.
          return if record.anonymized?

          SpreeKlaviyo::Profile.from_customer(record, use_database_ids: use_database_ids)
        else
          SpreeKlaviyo::Profile.from_order(record, use_database_ids: use_database_ids)
        end
      return if tombstone?(profile.email)

      integration.import_profile(profile)
    end
  end
end
