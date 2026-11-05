module SpreeKlaviyo
  # How every Klaviyo call is retried and reported.
  #
  # - 429: rescheduled after Klaviyo's Retry-After, with jitter and no attempt
  #   limit, since the limit always lifts and waiting holds no worker.
  # - 5xx, a timeout (no status) or a failed connection (status 0): retried
  #   with polynomial backoff, five attempts, then reported.
  # - Any other 4xx: reported once, since the same body cannot succeed.
  #
  # A report carries the status and Klaviyo's error codes and titles, never
  # the SDK's message, which appends the response headers and body.
  class BaseJob < Spree::BaseJob
    # The arguments carry customer email addresses, which ActiveJob would
    # otherwise log on every enqueue and perform.
    self.log_arguments = false

    queue_as { SpreeKlaviyo.queue }

    # Raised into Rails.error in place of the SDK's error.
    class RequestFailed < StandardError; end

    # When Klaviyo sends no usable Retry-After.
    DEFAULT_RETRY_AFTER = 60

    rescue_from KlaviyoAPI::ApiError, with: :handle_klaviyo_error
    # Declared after the rescue above so it wins for its subclass. ActiveJob
    # counts these attempts apart from 429 reschedules.
    retry_on SpreeKlaviyo::TransientError, wait: :polynomially_longer, attempts: 5 do |job, error|
      job.send(:report, error)
    end

    # A tombstone address from an erasure, which must never reach Klaviyo.
    #
    # @param email [String, nil]
    def self.tombstone?(email)
      email.blank? || email.to_s.downcase.end_with?("@#{Spree::Customers::Anonymize::REDACTED_DOMAIN}")
    end

    private

    def tombstone?(email)
      self.class.tombstone?(email)
    end

    def handle_klaviyo_error(error)
      error.code == 429 ? handle_rate_limit(error) : report(error)
    end

    def handle_rate_limit(error)
      if rate_limit_deadline_passed?
        report(error)
      else
        retry_job(wait: retry_after(error))
      end
    end

    # No deadline by default; an unsubscribe has one.
    def rate_limit_deadline_passed?
      false
    end

    def retry_after(error)
      headers = error.response_headers || {}
      seconds = (headers['Retry-After'] || headers['retry-after']).to_s
      seconds = seconds.match?(/\A\d+\z/) ? seconds.to_i : DEFAULT_RETRY_AFTER

      seconds + rand(0.0..[seconds * 0.1, 1].max)
    end

    def report(error)
      status = error.code
      summaries = Spree::Integrations::Klaviyo.error_summaries(error)

      Rails.error.report(
        RequestFailed.new("Klaviyo answered #{status || 'timeout'} to #{self.class.name}"),
        handled: true,
        source: 'spree_klaviyo',
        context: { job: self.class.name, status: status, errors: summaries }
      )
    end
  end
end
