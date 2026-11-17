module SpreeKlaviyo
  # Requests the deletion of a person's Klaviyo profile after an erasure.
  class DeleteProfileJob < BaseJob
    # @param integration [Spree::Integrations::Klaviyo]
    # @param email [String] the address from before the erasure
    def perform(integration, email)
      return if tombstone?(email)

      integration.request_profile_deletion(email)
    end
  end
end
