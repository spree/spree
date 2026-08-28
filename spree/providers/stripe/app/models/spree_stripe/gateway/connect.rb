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
        # As with the payment endpoint's pair: Spree registers the endpoint and
        # stores what Stripe hands back.
        preference :connect_webhook_signing_secret, :password, internal: true
        preference :connect_webhook_endpoint_id, :string, internal: true

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
        # A marketplace usually connects Stripe long before it has any sellers,
        # and the endpoint is registered when the gateway is saved — so by the
        # time the first seller onboards there may be nothing listening, and
        # the `account.updated` that says they can be paid never arrives.
        # Asked for here because this is the moment it starts to matter.
        ensure_connect_webhook_endpoint


        account_id = payout_account_for(seller) || create_connect_account(seller).tap do |created|
          seller.set_payout_account_reference(SpreeStripe::PayoutProvider, created)
        end

        Stripe::AccountLink.create(
          {
            account: account_id,
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
          connect_account_params(seller),
          api_options.merge(idempotency_key: account_idempotency_key(seller))
        ).id
      end

      def connect_account_params(seller)
        country_code = seller_country_code(seller)

        params = {
          country: country_code,
          email: seller.contact_email,
          business_profile: { name: seller.name },
          # What kind of account this is, stated as the three things that
          # actually differ rather than as a preset: the platform pays Stripe's
          # fees and owns the dispute relationship, which is what makes this a
          # marketplace rather than a referral, and the seller gets Stripe's
          # own hosted dashboard.
          #
          # Deliberately no `type: 'express'` beside it. The two are mutually
          # exclusive — Stripe refuses a request carrying both — and `type` is
          # deprecated in favour of stating the properties. One consequence
          # worth knowing: the account reads back as `type: "none"`, so nothing
          # may branch on that field.
          #
          # `requirement_collection` is left unset, which defaults to `stripe`
          # — Stripe collects what it needs through its hosted onboarding, and
          # `application` is not even allowed alongside an Express dashboard.
          controller: {
            fees: { payer: 'application' },
            losses: { payments: 'application' },
            stripe_dashboard: { type: 'express' }
          },
          capabilities: { transfers: { requested: true } },
          # Spree decides when a seller is settled, so Stripe must not also be
          # paying their balance out on a schedule of its own — two clocks on
          # one relationship, and the seller's own setting would be the one
          # that did nothing.
          settings: { payouts: { schedule: { interval: 'manual' } } },
          metadata: { spree_seller_id: seller.id }
        }

        params
      end

      # Identifies one attempt at creating this seller's account, not the seller.
      #
      # Two clicks a second apart must not open two Connect accounts, which is
      # what an idempotency key is for. But Stripe caches a failed response
      # against the key for a day, and refuses a retry whose parameters have
      # changed — so a key that never moves means a seller who hit a bad
      # request stays broken until tomorrow, and sees a confusing complaint
      # about mismatched parameters rather than the real problem.
      #
      # Rolling on the day keeps double-submit protection where it matters
      # while letting a fix take effect. `updated_at` moves whenever the
      # seller record is touched, which a failed attempt does.
      def account_idempotency_key(seller)
        stamp = seller.updated_at.to_i

        "spree-seller-#{seller.prefixed_id}-#{stamp}"
      end

      # Where the seller trades, which decides what currency and bank details
      # their account can hold. Falls back to the marketplace's own country —
      # Stripe would otherwise assume it anyway, and assuming it silently is
      # how a seller ends up with an account no local bank can receive.
      #
      # No service agreement is sent with it. A seller abroad needs the
      # recipient agreement only under Stripe's Global payouts product;
      # marketplaces on Connect's own cross-border payouts need the standard
      # one, and sending recipient there would wrongly bar the seller from
      # taking card payments. Which product a marketplace is on cannot be read
      # off a country code, so core sends neither and lets Stripe apply the
      # right default.
      def seller_country_code(seller)
        seller.billing_address&.country_code.presence || store.default_country_code
      end

      # Whether Stripe will let this seller be paid. It can go back to false —
      # a seller whose documents expire stops being payable, and the ledger
      # must stop crediting them rather than promise money nothing can send.
      def handle_account_updated(event)
        account = event.data.object
        seller = seller_for_account(account.id)
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
        seller = seller_for_account(event.account)
        return if seller.nil?

        payout = find_payout(seller, object)
        return if payout.nil? || payout.completed?

        if status == 'paid'
          Spree.seller_payout_complete_workflow.call(seller_payout: payout, reference: object.id)
        else
          payout.fail!
        end
      end

      # Which seller Stripe is talking about. A uniquely indexed read of the
      # account reference, scoped to this store's own sellers.
      #
      # Filed under this gem's own key rather than the store's configured
      # payout provider: Stripe issued the account, so Stripe is what it
      # belongs to, and a store still settling by hand must still be able to
      # onboard sellers to Connect.
      def seller_for_account(account_id)
        return if account_id.blank?

        Spree::Seller.with_payout_account(store, SpreeStripe::PayoutProvider, account_id).first
      end

      # @return [String, nil] the Connect account this seller already holds
      def payout_account_for(seller)
        seller.payout_account_reference(SpreeStripe::PayoutProvider)
      end

      # By Stripe's own id alone. Spree creates the payout, so it stored that
      # id when it did — an event naming an id we hold no settlement for is
      # about a payout somebody made outside Spree, and guessing which of our
      # settlements it meant would complete the wrong one.
      # By Stripe's id first, then by the one we sent with the request.
      #
      # The reference is normally stored the moment the payout is created, but
      # not when the answer to that call was lost — which is exactly the case
      # that most needs the webhook, since nothing else will tell the operator
      # whether the money moved. Stripe echoes our metadata back, so the id we
      # sent identifies the row when the id it assigned is not on file.
      def find_payout(seller, object)
        by_reference = seller.seller_payouts.find_by(reference: object.id)
        return by_reference if by_reference

        # A Stripe object raises for a key it does not carry rather than
        # answering nil, and an older payout has no metadata at all.
        return nil unless object.respond_to?(:metadata)

        payout_id = object.metadata['spree_seller_payout_id']
        return nil if payout_id.blank?

        seller.seller_payouts.find_by(id: payout_id, reference: nil)
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
      def ensure_connect_webhook_endpoint
        return if preferred_connect_webhook_signing_secret.present?

        SpreeStripe::CreateWebhookEndpointJob.perform_later(id, connect: true)
      end

      def create_connect_webhook_endpoint_async
        return if preferred_connect_webhook_signing_secret.present?

        SpreeStripe::CreateWebhookEndpointJob.perform_later(id, connect: true)
      end
    end
  end
end
