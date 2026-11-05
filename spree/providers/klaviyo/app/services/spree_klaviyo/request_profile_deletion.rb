module SpreeKlaviyo
  # `customers.anonymize.after_anonymize` handler: asks every active Klaviyo
  # integration to unsubscribe the person at once and delete their profile
  # later, since customers belong to every store and an erasure need not
  # name one.
  #
  # The unsubscribe is sent here as well as from the erased subscriptions,
  # because a deleted subscription's event names the store the erasure ran
  # in, not the one the subscription belonged to.
  class RequestProfileDeletion
    # Later than an unsubscribe can still be retrying (20 minutes), so the
    # erasure's unsubscribes reach Klaviyo before the profile is gone.
    DELAY = 30.minutes

    # @param workflow [Spree::Customers::Anonymize]
    def call(workflow)
      email = workflow.original_email
      # Erasing someone already erased has nothing left to send.
      return if SpreeKlaviyo::BaseJob.tombstone?(email)

      # Every store's integrations, deliberately.
      integrations = Spree::StoreScopeGuard.skip { Spree::Integrations::Klaviyo.active.to_a }
      jobs = integrations.flat_map do |integration|
        [SpreeKlaviyo::UpdateSubscriptionJob.new(integration, email, subscribed: false),
         SpreeKlaviyo::DeleteProfileJob.new(integration, email).set(wait: DELAY)]
      end
      ActiveJob.perform_all_later(jobs)
    end
  end
end
