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
      on the endpoint. An endpoint that cannot be saved is reported and
      skipped, so the rest are still switched off.
      Idempotent — endpoints already switched off are skipped.
    DESC
    task disable_unsafe_webhook_endpoints: :environment do
      disabled = 0
      failed = 0

      Spree::WebhookEndpoint.active.find_each do |endpoint|
        error = endpoint.url_error
        next unless Spree::WebhookEndpoint::REFUSED_URL_ERRORS.include?(error)

        reason = endpoint.errors.full_message(:url, endpoint.errors.generate_message(:url, error))
        begin
          endpoint.disable!(reason: reason, notify: false)
        rescue StandardError => e
          failed += 1
          Rails.error.report(e, context: { webhook_endpoint_id: endpoint.id })
          puts "  Could not switch off #{endpoint.prefixed_id} (#{endpoint.url}): #{e.message}"
          next
        end
        disabled += 1
        puts "  Switched off #{endpoint.prefixed_id} (#{endpoint.url}): #{reason}"
      end

      puts "  Switched off #{disabled} webhook endpoint(s)."
      puts "  Could not switch off #{failed} webhook endpoint(s); see the messages above." if failed.positive?
    end
  end
end
