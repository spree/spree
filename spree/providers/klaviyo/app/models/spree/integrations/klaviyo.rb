module Spree
  module Integrations
    # Per-store Klaviyo connection. The class and preference names are the
    # 1.x gem's, kept because upgraded stores have them stored.
    class Klaviyo < Spree::Integration
      # Klaviyo runs the whole double opt-in itself, so Spree's confirmation
      # (and its token) is never sent while the integration is active.
      NEWSLETTER_CONFIRMATION = 'spree/newsletter_mailer/email_confirmation'.freeze

      # Each switch hands Klaviyo the emails whose flow is triggered by the
      # event sent exactly when Spree would have sent them.
      REPLACED_EMAILS_BY_SWITCH = {
        sends_order_confirmation: %w[spree/order_mailer/confirm_email spree/order_group_mailer/confirm_email],
        sends_order_cancellation: %w[spree/order_mailer/cancel_email],
        sends_shipping_confirmation: %w[spree/fulfillment_mailer/fulfilled_email],
        sends_refund_confirmation: %w[spree/return_mailer/refunded_email]
      }.freeze

      preference :klaviyo_private_api_key, :password
      preference :default_newsletter_list_id, :string

      preference :sends_order_confirmation, :boolean, default: false
      preference :sends_order_cancellation, :boolean, default: false
      preference :sends_shipping_confirmation, :boolean, default: false
      preference :sends_refund_confirmation, :boolean, default: false
      # Sends the customer's database id as the profile's external_id, the
      # value 1.x sent, so profiles 1.x created keep matching.
      preference :use_database_ids_as_external_ids, :boolean, default: false

      def self.integration_group
        'marketing'
      end

      def self.logo_url
        'https://spreecommerce.org/docs/images/integrations/logos/klaviyo.png'
      end

      def self.docs_url
        'https://spreecommerce.org/docs/integrations/marketing/klaviyo'
      end

      # Fallback for hosts without the gem's translations; the localized
      # description in config/locales wins.
      def self.description
        'Customer profiles, newsletter sign-ups and order events in Klaviyo, for flows, segments and campaigns.'
      end

      # The SDK's default is no timeout at all.
      TIMEOUT_SECONDS = 10

      # @return [Array<String>]
      def replaced_customer_emails
        REPLACED_EMAILS_BY_SWITCH.each_with_object([NEWSLETTER_CONFIRMATION]) do |(switch, keys), emails|
          emails.concat(keys) if public_send(:"preferred_#{switch}")
        end
      end

      # Reads the configured list, which proves the key, its lists:read scope
      # and the list id. A key missing a write scope still connects; the first
      # job needing it is refused and reported. The list's opt-in setting is
      # the merchant's choice and is not checked.
      def can_connect?
        missing = { klaviyo_private_api_key: preferred_klaviyo_private_api_key,
                    default_newsletter_list_id: preferred_default_newsletter_list_id }.find { |_, value| value.blank? }
        if missing
          self.connection_error_message = I18n.t("spree.integrations.klaviyo.missing_#{missing.first}")
          return false
        end

        call(:get, "/api/lists/#{preferred_default_newsletter_list_id}") do |client|
          KlaviyoAPI::ListsApi.new(client).get_list_with_http_info(preferred_default_newsletter_list_id)
        end
        true
      rescue KlaviyoAPI::ApiError => e
        self.connection_error_message = self.class.error_details(e).first.presence || I18n.t('spree.integrations.klaviyo.connection_failed')
        false
      end

      # @param profile [SpreeKlaviyo::Profile]
      def import_profile(profile)
        call(:post, '/api/profile-import') do |client|
          KlaviyoAPI::ProfilesApi.new(client).create_or_update_profile_with_http_info(profile.to_body)
        end
      end

      # Klaviyo applies the list's own opt-in setting: a double opt-in list
      # sends its confirmation, a single opt-in list subscribes at once.
      #
      # @param email [String]
      def subscribe(email)
        body = subscription_body('profile-subscription-bulk-create-job', email, 'SUBSCRIBED')

        call(:post, '/api/profile-subscription-bulk-create-jobs') do |client|
          KlaviyoAPI::ProfilesApi.new(client).bulk_subscribe_profiles_with_http_info(body)
        end
      end

      # Revokes email-marketing consent, which in Klaviyo belongs to the
      # account, not only the list.
      #
      # @param email [String]
      def unsubscribe(email)
        body = subscription_body('profile-subscription-bulk-delete-job', email, 'UNSUBSCRIBED')

        call(:post, '/api/profile-subscription-bulk-delete-jobs') do |client|
          KlaviyoAPI::ProfilesApi.new(client).bulk_unsubscribe_profiles_with_http_info(body)
        end
      end

      # @param metric_event [SpreeKlaviyo::MetricEvent]
      def create_event(metric_event)
        call(:post, '/api/events') do |client|
          KlaviyoAPI::EventsApi.new(client).create_event_with_http_info(metric_event.to_body)
        end
      end

      # Needs the data-privacy:write scope, which 1.x keys lack.
      #
      # @param email [String]
      def request_profile_deletion(email)
        body = { data: { type: 'data-privacy-deletion-job',
                         attributes: { profile: { data: { type: 'profile', attributes: { email: email } } } } } }

        call(:post, '/api/data-privacy-deletion-jobs') do |client|
          KlaviyoAPI::DataPrivacyApi.new(client).request_profile_deletion_with_http_info(body)
        end
      end

      # Klaviyo's own error details, never the SDK's message, which appends
      # the response headers and body.
      #
      # @param error [KlaviyoAPI::ApiError]
      # @return [Array<String>]
      def self.error_details(error)
        errors_in(error).filter_map { |entry| entry['detail'] }
      end

      # The codes and titles a report may carry.
      #
      # @param error [KlaviyoAPI::ApiError]
      # @return [Array<Hash>]
      def self.error_summaries(error)
        errors_in(error).map { |entry| entry.slice('code', 'title') }
      end

      def self.errors_in(error)
        body = error.response_body.presence
        return [] unless body

        parsed = JSON.parse(body)
        # A proxy in front of Klaviyo may answer with JSON that is not an object.
        parsed.is_a?(Hash) ? Array(parsed['errors']).grep(Hash) : []
      rescue JSON::ParserError
        []
      end
      private_class_method :errors_in

      private

      # One SDK client per call, carrying this integration's key: the SDK's
      # global configuration holds one key for the whole process, and two
      # stores would send each other's data.
      def api_client
        configuration = KlaviyoAPI::Configuration.new do |config|
          config.api_key['Klaviyo-API-Key'] = preferred_klaviyo_private_api_key
          config.api_key_prefix['Klaviyo-API-Key'] = 'Klaviyo-API-Key'
          config.timeout = TIMEOUT_SECONDS
          config.debugging = false
        end

        KlaviyoAPI::ApiClient.new(configuration)
      end

      # Logs method, path, status and duration; never a body or a header,
      # which carry names, emails and addresses. The block calls an SDK
      # `_with_http_info` method, whose status the log line reports. A failure
      # worth retrying is raised as {SpreeKlaviyo::TransientError}.
      #
      # @return [Object] the response data
      def call(method, path)
        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        data, status, = yield api_client
        data
      rescue KlaviyoAPI::ApiError => e
        status = e.code.nil? ? 'timeout' : e.code
        raise e unless SpreeKlaviyo::TransientError.transient?(e.code)

        raise SpreeKlaviyo::TransientError.new(code: e.code, response_headers: e.response_headers, response_body: e.response_body)
      ensure
        duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        Rails.logger.info("[Klaviyo] #{method.to_s.upcase} #{path} -> #{status} (#{duration_ms}ms)")
      end

      def subscription_body(type, email, consent)
        {
          data: {
            type: type,
            attributes: {
              profiles: {
                data: [{ type: 'profile', attributes: { email: email, subscriptions: { email: { marketing: { consent: consent } } } } }]
              }
            },
            relationships: { list: { data: { type: 'list', id: preferred_default_newsletter_list_id } } }
          }
        }
      end
    end
  end
end
