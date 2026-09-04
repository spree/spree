module SpreeAvalara
  # Per-store AvaTax credentials. Preference names are deliberately identical to
  # the legacy `spree_avatax_official` integration's, so upgrading a store is a
  # matter of retyping the row — its serialized preferences carry over untouched.
  class Integration < Spree::Integration
    SANDBOX_ENDPOINT = 'https://sandbox-rest.avatax.com'.freeze
    PRODUCTION_ENDPOINT = 'https://rest.avatax.com'.freeze

    preference :account_number, :string
    preference :license_key, :password
    # Sandbox by default: a merchant connecting for the first time should not be
    # filing live documents before they have looked at one. Avalara publishes
    # these two hosts and no others, and the legacy extension offered the same
    # pair under the same labels, so a merchant sees the choice they already
    # know rather than a URL to type.
    preference :endpoint, :string, default: SANDBOX_ENDPOINT,
                                   options: { SANDBOX_ENDPOINT => 'Sandbox',
                                              PRODUCTION_ENDPOINT => 'Production' }
    preference :company_code, :string

    preference :address_validation_enabled, :boolean, default: false
    preference :commit_transaction_enabled, :boolean, default: true
    preference :show_rate_in_label, :boolean, default: false

    # Without these a half-filled credential set saves and then fails at
    # activation with a vendor error, which reads as an Avalara outage rather
    # than a missing field.
    validates :preferred_account_number, :preferred_license_key, :preferred_company_code, presence: true

    # The picker in the dashboard only offers these two, but the admin API takes
    # a free-form preferences hash, so the allowlist has to be enforced here as
    # well: the value is handed to the HTTP client along with the credentials,
    # and an arbitrary host turns this into a way to make the server issue
    # requests wherever an admin points it — internal services and cloud
    # metadata included — with the reply readable through the connection test.
    validates :preferred_endpoint, inclusion: { in: [SANDBOX_ENDPOINT, PRODUCTION_ENDPOINT] }

    def self.integration_group
      'tax'
    end

    def self.integration_name
      'Avalara AvaTax'
    end

    # Avalara's own mark, hotlinked. The path is year-versioned, so it may
    # eventually stop resolving; the gallery falls back to a letter avatar for an
    # unreachable logo, so that degrades rather than breaks.
    def self.logo_url
      'https://www.avalara.com/etc.clientlibs/avalara/clientlibs/clientlib-ava-26-site/resources/favicons/favicon.svg'
    end

    # Fallback for hosts without the gem's translations; the localized
    # description in config/locales wins.
    def self.description
      'Calculate sales tax, VAT and GST at checkout through your Avalara AvaTax account.'
    end

    # The connected integration a store calculates tax through, or nil.
    #
    # @param store [Spree::Store, nil]
    # @return [SpreeAvalara::Integration, nil]
    def self.active_for(store)
      store&.integrations&.active&.find_by(type: name)
    end

    # @param store [Spree::Store, nil]
    # @return [SpreeAvalara::Integration]
    # @raise [SpreeAvalara::NotConfiguredError] when the store has none
    def self.active_for!(store)
      active_for(store) ||
        raise(SpreeAvalara::NotConfiguredError,
              "Store #{store&.id.inspect} has no active Avalara integration")
    end

    # @return [SpreeAvalara::Client]
    def client
      @client ||= SpreeAvalara::Client.new(
        account_number: preferred_account_number,
        license_key: preferred_license_key,
        endpoint: preferred_endpoint,
        company_code: preferred_company_code
      )
    end

    # Verifies the credentials with a ping, the one AvaTax call that costs
    # nothing and files nothing. It reports authentication rather than raising on
    # a bad key, so a successful response still has to be read.
    #
    # @return [Boolean]
    def can_connect?
      body = client.ping
      return true if body.is_a?(Hash) && body['authenticated']

      self.connection_error_message =
        if body.is_a?(Hash) && body.key?('authenticated')
          Spree.t('integrations.avalara.errors.invalid_credentials')
        else
          Spree.t('integrations.avalara.errors.connection_failed')
        end

      false
    rescue SpreeAvalara::RequestError => error
      self.connection_error_message = request_failure_message(error)

      false
    rescue StandardError => error
      self.connection_error_message = error.message

      false
    end

    private

    # A request with no status was never answered, so the network error is the
    # only thing worth showing. Anything Avalara did answer speaks for itself
    # when it explained why.
    def request_failure_message(error)
      return error.message if error.status.nil?

      (error.details.is_a?(Hash) && error.details['message'].presence) ||
        Spree.t('integrations.avalara.errors.connection_failed')
    end
  end
end
