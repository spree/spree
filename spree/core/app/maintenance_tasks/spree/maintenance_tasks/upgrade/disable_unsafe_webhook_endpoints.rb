module Spree
  module MaintenanceTasks
    module Upgrade
      # 5.6 → 6.0: switches off webhook endpoints whose URL Spree now refuses
      # for good — malformed, or an internal or private address. Endpoints
      # saved before these checks can still hold one (6.0.0.rc5 accepted
      # http://127.1/); delivery already refuses them, and this stops the
      # failed attempts.
      #
      # Plain-http endpoints keep running until their next save, and so do
      # hosts that fail to resolve during the run, which may be a passing DNS
      # failure. An endpoint that cannot be saved is counted and reported
      # rather than failing the run, so the rest are still switched off.
      class DisableUnsafeWebhookEndpoints < Spree::MaintenanceTask
        supports_dry_run

        def collection
          Spree::WebhookEndpoint.active.order(:id)
        end

        def process(endpoint)
          error = endpoint.url_error
          return unless Spree::WebhookEndpoint::REFUSED_URL_ERRORS.include?(error)
          return tally(:would_switch_off) if dry_run?

          endpoint.disable!(reason: endpoint.errors.full_message(:url, endpoint.errors.generate_message(:url, error)), notify: false)
          tally(:switched_off)
        rescue StandardError => e
          Rails.error.report(e, context: { webhook_endpoint_id: endpoint.id })
          tally(:failed)
        end
      end
    end
  end
end
