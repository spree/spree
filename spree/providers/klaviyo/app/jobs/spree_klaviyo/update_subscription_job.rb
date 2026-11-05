module SpreeKlaviyo
  # Subscribes or unsubscribes an email address. Takes the address rather than
  # the subscriber row, which is gone after newsletter_subscriber.deleted.
  class UpdateSubscriptionJob < BaseJob
    # An unsubscribe gives up after this, so it always reaches Klaviyo before
    # an erasure's profile deletion, enqueued 30 minutes after it.
    UNSUBSCRIBE_DEADLINE = 20.minutes

    # When the job was first enqueued, kept across reschedules.
    attr_accessor :first_enqueued_at

    def serialize
      self.first_enqueued_at ||= Time.current
      super.merge('klaviyo_first_enqueued_at' => first_enqueued_at.utc.iso8601(6))
    end

    def deserialize(job_data)
      super
      self.first_enqueued_at = Time.iso8601(job_data['klaviyo_first_enqueued_at']) if job_data['klaviyo_first_enqueued_at']
    end

    # @param integration [Spree::Integrations::Klaviyo]
    # @param email [String]
    # @param subscribed [Boolean] true to subscribe, false to unsubscribe
    def perform(integration, email, subscribed:)
      return if tombstone?(email)

      subscribed ? integration.subscribe(email) : integration.unsubscribe(email)
    end

    private

    def rate_limit_deadline_passed?
      arguments.last[:subscribed] == false && first_enqueued_at.present? &&
        Time.current - first_enqueued_at > UNSUBSCRIBE_DEADLINE
    end
  end
end
