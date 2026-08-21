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

        became_payable = account.payouts_enabled && seller.payouts_enabled_at.nil?
        seller.update!(payouts_enabled_at: account.payouts_enabled ? (seller.payouts_enabled_at || Time.current) : nil)

        # Anything they earned while unverified is owed and still pending, and
        # this is the moment it can finally be sent.
        Spree::SellerTransfers::ExecutePendingJob.perform_later(seller.id) if became_payable
      end

      # Stripe's payout belongs to a connected account rather than to one of
      # our settlements, so the seller is found by the account the event names.
      #
      # Matching the settlement is by Stripe's own id first. Stripe redelivers
      # a webhook on any non-2xx or timeout, and without that match a second
      # delivery would skip the settlement it already completed and land on the
      # next one still owed — marking an unrelated payout paid.
      def handle_payout(event, status)
        object = event.data.object
        seller = store.sellers.find_by(payout_account_reference: event.account)
        return if seller.nil?

        payout = find_payout(seller, object)
        return if payout.nil? || payout.completed?

        if status == 'paid'
          Spree.seller_payout_complete_workflow.call(seller_payout: payout, reference: object.id)
        else
          payout.fail!
        end
      end

      def find_payout(seller, object)
        seller.seller_payouts.find_by(reference: object.id) ||
          seller.seller_payouts.owed.where(currency: object.currency.to_s.upcase).order(:created_at).first
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

      # The stored secret is the loop guard, as on the payment endpoint —
      # registration writes it back through `update!`, which re-runs this.
      #
      # Deliberately not gated on the store having sellers. The ordinary setup
      # order is to connect Stripe first and invite sellers afterwards, and
      # nothing about creating a seller saves the gateway — so that guard meant
      # the endpoint was never registered at all, and `account.updated` never
      # arrived to say who could be paid.
      def create_connect_webhook_endpoint_async
        return if preferred_connect_webhook_signing_secret.present?

        SpreeStripe::CreateWebhookEndpointJob.perform_later(id, connect: true)
      end
    end
  end
end
