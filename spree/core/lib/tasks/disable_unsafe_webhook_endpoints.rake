namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Switches off webhook endpoints whose URL Spree now refuses for good: a
      malformed URL, or an internal or private address. Endpoints saved before
      these checks can still hold one — 6.0.0.rc5, for example, accepted
      http://127.1/ and http://[::1]/. Delivery already refuses them; this
      stops the failed attempts.

      Plain-http endpoints keep running: HTTPS is required the next time one
      is saved. So do endpoints whose host does not resolve during the run,
      which may be a passing DNS failure. No email is sent; the reason is kept
      on the endpoint.
      Idempotent — endpoints already switched off are skipped.
    DESC
    task disable_unsafe_webhook_endpoints: :environment do
      disabled = 0

      Spree::WebhookEndpoint.active.find_each do |endpoint|
        error = endpoint.url_error
        next unless Spree::WebhookEndpoint::REFUSED_URL_ERRORS.include?(error)

        reason = endpoint.errors.full_message(:url, endpoint.errors.generate_message(:url, error))
        endpoint.disable!(reason: reason, notify: false)
        disabled += 1
        puts "  Switched off #{endpoint.prefixed_id} (#{endpoint.url}): #{reason}"
      end

      puts "  Switched off #{disabled} webhook endpoint(s)."
    end
  end
end
