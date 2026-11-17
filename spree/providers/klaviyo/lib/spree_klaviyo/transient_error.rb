module SpreeKlaviyo
  # A Klaviyo failure worth retrying: a 5xx, a timeout (no status) or a failed
  # connection (status 0). Raised in place of the SDK's error so the jobs can
  # retry it apart from rate limits.
  class TransientError < KlaviyoAPI::ApiError
    # The SDK's message appends the response headers and body, and ActiveJob
    # logs the message on every retry.
    def message
      "Klaviyo answered #{code.nil? ? 'with a timeout' : code}"
    end

    # @param code [Integer, nil] 0 or nil for a timeout or a failed connection
    def self.transient?(code)
      code.nil? || code.zero? || code >= 500
    end
  end
end
