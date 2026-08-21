module SpreeStripe
  class Gateway < ::Spree::Gateway
    # The marketplace half of the gateway: paying sellers out of the account
    # that charged their customers.
    #
    # This lives on the gateway rather than in settings of its own because it
    # is the same Stripe account either way. A marketplace pays sellers from
    # the money it took, and a transfer signed with a different key than the
    # charge cannot name that charge as its funding source — so a second copy
    # of the credentials could only ever drift out of agreement with the first.
    #
    # It does need a **second webhook endpoint**, though, and that is not a
    # detail. Stripe scopes events by where they originate: the marketplace's
    # own charges on one subscription, everything happening inside a seller's
    # connected account on another, each with its own signing secret. Adding
    # the seller events to the payment endpoint would not widen it — it would
    # switch it over, and the payment webhooks would stop arriving.
    module Connect
      extend ActiveSupport::Concern

      # `account.updated` — onboarding is finished when Stripe says the account
      # can receive transfers, which may be days after the seller stops typing.
      # `payout.*` — Stripe settling a connected account's balance to its bank,
      # which is what completes a payout here.
      CONNECT_EVENTS = %w[
        account.updated
        payout.paid
        payout.failed
      ].freeze

      included do
        preference :connect_webhook_signing_secret, :password
        preference :connect_webhook_endpoint_id, :string

        after_commit :create_connect_webhook_endpoint_async, on: %i[create update]
      end

      # Verifies and acts on one Connect event.
      #
      # @param raw_body [String]
      # @param headers [Hash]
      # @raise [Spree::PaymentMethod::WebhookSignatureError]
      def handle_payout_webhook(raw_body, headers)
        event = verify_connect_webhook_signature(raw_body, headers)

        case event.type
        when 'account.updated' then handle_account_updated(event)
        when 'payout.paid' then handle_payout(event, 'paid')
        when 'payout.failed' then handle_payout(event, 'failed')
        end
      end

      # Gives a seller a Stripe Express account and a link to finish setting it
      # up. Express is the right shape for a marketplace: Stripe collects
      # identity and bank details on its own pages, so the marketplace never
      # handles them and inherits Stripe's checks rather than building its own.
      #
      # The link is minted per call rather than stored — Stripe's onboarding
      # links are single-use and short-lived by design.
      #
      # @param seller [Spree::Seller]
      # @param refresh_url [String] where Stripe sends a seller whose link expired
      # @param return_url [String] where Stripe sends them when they finish
      # @return [String] the onboarding URL
      def create_connect_account_link(seller:, refresh_url:, return_url:)
        seller.update!(payout_account_reference: create_connect_account(seller)) if seller.payout_account_reference.blank?

        Stripe::AccountLink.create(
          {
            account: seller.payout_account_reference,
            refresh_url: refresh_url,
            return_url: return_url,
            type: 'account_onboarding'
          },
          api_options
        ).url
      end

      # @return [Hash] what every Stripe call from this gateway is signed with
      def api_options
        { api_key: preferred_secret_key }
      end

      # Where Stripe sends events originating in sellers' connected accounts.
      # @return [String, nil]
      def connect_webhook_url
        return nil unless store

        "#{store.url_or_custom_domain}/api/v3/webhooks/payouts/#{prefixed_id}"
      end

      def create_connect_webhook_endpoint
        SpreeStripe::CreateGatewayWebhooks.new.call(payment_method: self, connect: true)
      end

      private

      def create_connect_account(seller)
        Stripe::Account.create(
          {
            type: 'express',
            email: seller.contact_email,
            business_profile: { name: seller.name },
            # The platform pays Stripe's fees and owns the dispute
            # relationship, which is what makes this a marketplace rather than
            # a referral.
            controller: {
              fees: { payer: 'application' },
              losses: { payments: 'application' },
              stripe_dashboard: { type: 'express' }
            },
            capabilities: { transfers: { requested: true } },
            metadata: { spree_seller_id: seller.id }
          },
          api_options.merge(idempotency_key: "spree-seller-#{seller.prefixed_id}")
        ).id
      end

      # Whether Stripe will let this seller be paid. It can go back to false —
      # a seller whose documents expire stops being payable, and the ledger
      # must stop crediting them rather than promise money nothing can send.
      def handle_account_updated(event)
        account = event.data.object
        seller = store.sellers.find_by(payout_account_reference: account.id)
        return if seller.nil?

        seller.update!(payouts_enabled_at: account.payouts_enabled ? (seller.payouts_enabled_at || Time.current) : nil)
      end

      # Stripe's payout belongs to a connected account rather than to one of
      # our settlements, so the seller is found by the account the event names
      # and the settlement by being the one still owed in that currency.
      def handle_payout(event, status)
        object = event.data.object
        seller = store.sellers.find_by(payout_account_reference: event.account)
        return if seller.nil?

        payout = seller.seller_payouts.owed.where(currency: object.currency.to_s.upcase).order(:created_at).first
        return if payout.nil?

        if status == 'paid'
          Spree.seller_payout_complete_workflow.call(seller_payout: payout, reference: object.id)
        else
          payout.update!(status: 'failed')
        end
      end

      def verify_connect_webhook_signature(raw_body, headers)
        signature = headers['HTTP_STRIPE_SIGNATURE']

        connect_webhook_signing_secrets.each do |secret|
          return Stripe::Webhook.construct_event(raw_body, signature, secret)
        rescue Stripe::SignatureVerificationError
          next
        rescue JSON::ParserError
          raise Spree::PaymentMethod::WebhookSignatureError, 'Malformed webhook payload'
        end

        raise Spree::PaymentMethod::WebhookSignatureError, 'Invalid webhook signature'
      end

      # Development only, matching the payment endpoint: the Stripe CLI signs
      # forwarded events with its own secret rather than the endpoint's.
      def connect_webhook_signing_secrets
        secrets = [preferred_connect_webhook_signing_secret]
        secrets << ENV['STRIPE_CONNECT_SIGNING_SECRET'] if Rails.env.development?
        secrets.select(&:present?)
      end

      # Only registered once the store actually has sellers: an ordinary
      # merchant account has no connected accounts to hear about, and the
      # endpoint would receive nothing. Also the loop guard, as on the payment
      # endpoint — registration writes the secret back through `update!`.
      def create_connect_webhook_endpoint_async
        return if preferred_connect_webhook_signing_secret.present?
        return unless store&.sellers&.exists?

        SpreeStripe::CreateWebhookEndpointJob.perform_later(id, connect: true)
      end
    end
  end
end
