module Spree
  class PaymentMethod < Spree.base_class
    has_prefix_id :pm  # Stripe: pm_

    acts_as_paranoid
    # Scoped like every other store-owned list (Collection, Market,
    # PriceList): without it, position assignment and reordering shift rows
    # across ALL stores.
    acts_as_list scope: :store_id

    include Spree::SingleStoreResource
    include Spree::StorePreferences
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::CaptureMethod
    if defined?(Spree::Security::PaymentMethods)
      include Spree::Security::PaymentMethods
    end

    # Blank falls back to the store, so a method only overrides when a merchant
    # deliberately picks one — the meaning the auto_capture boolean already had.
    normalizes :capture_method, with: ->(value) { value.presence }

    validates :capture_method, inclusion: { in: Spree::CaptureMethod::CAPTURE_METHODS }, allow_nil: true

    # Provider subclasses override the payment-session methods wholesale, so
    # tracing instrumentation must be prepended to each subclass — prepended
    # to this base class it would sit below the override and never run.
    #
    # @param subclass [Class] the inheriting payment method class
    # @return [void]
    def self.inherited(subclass)
      super
      subclass.prepend(Spree::PaymentMethod::SessionInstrumentation)
    end

    scope :active,    -> { where(active: true).order(position: :asc) }
    # Every tri-state display_on value passed the old filter, so availability
    # only ever meant "active".
    scope :available, -> { active }
    scope :store_credit, -> { where(type: 'Spree::PaymentMethod::StoreCredit') }

    # Customer-facing methods vs backoffice-only ones (manual check entry,
    # internal wire transfers). The backoffice always sees every method.
    scope :storefront_visible, -> { where(storefront_visible: true) }
    scope :admin_only, -> { where(storefront_visible: false) }

    # Real column, so admin clients filter it directly — no ransacker needed.
    self.whitelisted_ransackable_attributes = %w[storefront_visible]

    after_initialize :set_name, if: :new_record?

    validates :name, presence: true
    validates :store, presence: true
    validates :storefront_visible, inclusion: { in: [true, false] }
    normalizes :name, with: ->(value) { value&.to_s&.squish&.presence }

    belongs_to :store, class_name: 'Spree::Store'

    has_many :payments, class_name: 'Spree::Payment', inverse_of: :payment_method, dependent: :nullify
    has_many :credit_cards, class_name: 'Spree::CreditCard', dependent: :destroy # CCs are soft deleted

    has_many :payment_sessions, class_name: 'Spree::PaymentSession', dependent: :destroy
    has_many :payment_setup_sessions, class_name: 'Spree::PaymentSetupSession', dependent: :destroy
    has_many :gateway_customers, class_name: 'Spree::GatewayCustomer', dependent: :destroy

    def self.providers
      Spree.payment_methods
    end

    # Gateways predate `registers_subclasses_via` and expose their registry as
    # `providers`; declaring it keeps subclass resolution to a single rule.
    registers_subclasses_via { providers }

    def provider_class
      raise ::NotImplementedError, 'You must implement provider_class method for this gateway.'
    end

    # The class that will process payments for this payment type, used for @payment.source
    # e.g. CreditCard in the case of a the Gateway payment type
    # nil means the payment method doesn't require a source e.g. check
    def payment_source_class
      return unless source_required?

      raise ::NotImplementedError, 'You must implement payment_source_class method for this gateway.'
    end

    # The class used for payment sessions with this payment method.
    # Override in gateway subclasses to provide a provider-specific session class
    # that inherits from Spree::PaymentSession (STI).
    # nil means the payment method doesn't support payment sessions.
    def payment_session_class
      nil
    end

    # Risk codes the gateway can derive from a payment source — the address and
    # card-verification check results the provider recorded when the source was
    # created. Payment assigns them at creation when the gateway response path
    # did not supply any, so session-created payments still feed
    # +Spree::Payment.risky+ and order risk analysis.
    #
    # Override in gateway subclasses that store check results on their sources.
    #
    # @param _source [Spree::PaymentSource, Spree::CreditCard]
    # @return [Hash, nil] +{ avs_response:, cvv_response_code: }+ or nil
    def risk_codes_for(_source)
      nil
    end

    # Creates a payment session via the provider.
    # Override in gateway subclasses to implement provider-specific session creation.
    def create_payment_session(order:, amount: nil, external_data: {})
      raise ::NotImplementedError, 'You must implement create_payment_session method for this gateway.'
    end

    # Updates an existing payment session via the provider.
    # Override in gateway subclasses to implement provider-specific session updates.
    def update_payment_session(payment_session:, amount: nil, external_data: {})
      raise ::NotImplementedError, 'You must implement update_payment_session method for this gateway.'
    end

    # Completes a payment session via the provider.
    # Override in gateway subclasses to implement provider-specific session completion.
    #
    # Responsibilities:
    # - Verify payment status with the provider
    # - Create/update the Spree::Payment record
    # - Patch order data from provider (e.g. wallet billing address)
    # - Transition payment session to completed/failed
    #
    # Must NOT complete the order — that is handled by Carts::Complete
    # (called by the frontend or by the webhook handler).
    def complete_payment_session(payment_session:, params: {})
      raise ::NotImplementedError, 'You must implement complete_payment_session method for this gateway.'
    end

    # Parses an incoming webhook payload from the payment provider.
    # Override in gateway subclasses to implement provider-specific webhook parsing.
    #
    # @param raw_body [String] the raw request body
    # @param headers [Hash] the request headers
    # @return [Hash, nil] normalized result or nil for unsupported events
    #   { action: :captured/:authorized/:failed/:canceled,
    #     payment_session: <Spree::PaymentSession>,
    #     metadata: {} }
    # @raise [Spree::PaymentMethod::WebhookSignatureError] if signature is invalid
    def parse_webhook_event(raw_body, headers)
      raise ::NotImplementedError, 'You must implement parse_webhook_event method for this gateway.'
    end

    # Returns the webhook URL for this payment method.
    # @return [String, nil]
    def webhook_url
      return nil unless store

      "#{store.url_or_custom_domain}/api/v3/webhooks/payments/#{prefixed_id}"
    end

    class WebhookSignatureError < StandardError; end

    # Whether this payment method supports setup sessions (saving payment methods for future use).
    # Override in gateway subclasses that support tokenization without a payment.
    def setup_session_supported?
      false
    end

    # The class used for payment setup sessions with this payment method.
    # Override in gateway subclasses to provide a provider-specific session class.
    def payment_setup_session_class
      nil
    end

    # Creates a payment setup session via the provider for saving a payment method.
    # Override in gateway subclasses to implement provider-specific setup session creation.
    def create_payment_setup_session(customer:, external_data: {})
      raise ::NotImplementedError, "#{self.class.name} does not implement #create_payment_setup_session"
    end

    # Completes a payment setup session via the provider.
    # Override in gateway subclasses to implement provider-specific setup session completion.
    def complete_payment_setup_session(setup_session:, params: {})
      raise ::NotImplementedError, "#{self.class.name} does not implement #complete_payment_setup_session"
    end

    def method_type
      type.demodulize.downcase
    end

    def default_name
      self.class.name.demodulize.titleize.gsub(/Gateway/, '').strip
    end

    def payment_icon_name
      type.demodulize.gsub(/(^Spree::Gateway::|Gateway$)/, '').downcase.gsub(/\s+/, '').strip
    end

    def self.find_with_destroyed(*args)
      unscoped { find(*args) }
    end

    def confirmation_required?
      false
    end

    def payment_profiles_supported?
      false
    end

    def source_required?
      true
    end

    def session_required?
      false
    end

    def show_in_admin?
      true
    end

    # Custom gateways should redefine this method. See Gateway implementation
    # as an example
    def reusable_sources(_order)
      []
    end

    # The method's own choice when it has one, otherwise the store's. A legacy
    # auto_capture of true is still honored for installs that set it before
    # capture_method existed and have not run the migration task.
    #
    # auto_capture false is NOT read as manual: it only ever recorded "not at
    # checkout" and could not distinguish dispatch from staff collection, so
    # the store decides — the same rows the migration deliberately leaves
    # empty. Reading it as manual would exclude those payments from dispatch
    # capture while still letting the goods go out.
    #
    # @return [String] one of Spree::CaptureMethod::CAPTURE_METHODS
    def resolved_capture_method
      return capture_method if capture_method.present?
      return 'checkout' if auto_capture

      store_preference(:capture_method).presence || Spree::CaptureMethod::DEFAULT_CAPTURE_METHOD
    end

    # @deprecated Use #capture_at_checkout?; removed in 6.1. Deliberately does
    #   not warn — it runs on every payment and would flood the logs.
    def auto_capture?
      capture_at_checkout?
    end

    def supports?(_source)
      true
    end

    # Settles a payment for a canceled order. A gateway releases what it never
    # drew on; what it does with money already taken depends on `refund:`,
    # which is false when the operator asked to keep it — an adapter that
    # cannot void a captured charge must then leave it alone rather than
    # refunding anyway.
    #
    # @param _response [String] the gateway's authorization for the payment
    # @param _payment [Spree::Payment, nil]
    # @param refund [Boolean] whether money already captured may be returned
    def cancel(_response, _payment = nil, refund: true)
      raise ::NotImplementedError, 'You must implement cancel method for this payment method.'
    end

    def store_credit?
      self.class == Spree::PaymentMethod::StoreCredit
    end

    # Custom PaymentMethod/Gateway can redefine this method to check method
    # availability for concrete order.
    def available_for_order?(order)
      !order.covered_by_store_credit?
    end

    def available_for_store?(store)
      return true if store.blank?

      store_id == store.id
    end

    def public_preferences
      public_preference_keys.each_with_object({}) do |key, hash|
        hash[key] = preferences[key]
      end
    end

    # @deprecated Use {#storefront_visible?}; removed in 6.1.
    def available_on_front_end?
      Spree::Deprecation.warn('Spree::PaymentMethod#available_on_front_end? is deprecated and will be removed in Spree 6.1. Use #storefront_visible? instead.')
      storefront_visible?
    end

    # @deprecated Use {#storefront_visible}; removed in 6.1.
    def display_on
      Spree::Deprecation.warn('Spree::PaymentMethod#display_on is deprecated and will be removed in Spree 6.1. Use #storefront_visible instead.')
      storefront_visible? ? 'both' : 'back_end'
    end

    # @deprecated Use {#storefront_visible=}; removed in 6.1.
    def display_on=(value)
      Spree::Deprecation.warn('Spree::PaymentMethod#display_on= is deprecated and will be removed in Spree 6.1. Use #storefront_visible= instead.')
      self.storefront_visible = value.to_s != 'back_end'
    end

    protected

    def public_preference_keys
      []
    end

    def set_name
      self.name ||= default_name
    end
  end
end
