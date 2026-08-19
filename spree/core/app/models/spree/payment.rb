require_dependency 'spree/payment/processing'

module Spree
  class Payment < Spree.base_class
    has_prefix_id :py  # Stripe: py_

    include Spree::DerivedNumber
    derives_number infix: 'P'
    include Spree::HasCustomFields
    include Spree::Metadata
    if defined?(Spree::Security::Payments)
      include Spree::Security::Payments
    end

    extend Spree::DisplayMoney

    include Spree::Payment::Processing
    include Spree::Payment::CustomEvents

    publishes_lifecycle_events

    NON_RISKY_AVS_CODES = ['B', 'D', 'H', 'J', 'M', 'Q', 'T', 'V', 'X', 'Y'].freeze
    RISKY_AVS_CODES     = ['A', 'C', 'E', 'F', 'G', 'I', 'K', 'L', 'N', 'O', 'P', 'R', 'S', 'U', 'W', 'Z'].freeze
    INVALID_STATUSES    = %w(failed invalid void).freeze
    INVALID_STATES      = INVALID_STATUSES
    deprecate_constant :INVALID_STATES

    with_options inverse_of: :payments do
      belongs_to :order, class_name: 'Spree::Order', touch: true, optional: true
      belongs_to :cart, class_name: 'Spree::Cart', optional: true
      belongs_to :payment_method, -> { with_deleted }, class_name: 'Spree::PaymentMethod'
    end
    belongs_to :source, polymorphic: true

    validate :exactly_one_owner

    has_many :offsets, -> { offset_payment }, class_name: 'Spree::Payment', foreign_key: :source_id
    has_many :capture_events, class_name: 'Spree::PaymentCaptureEvent'
    has_many :refunds, inverse_of: :payment

    has_one :payment_session, class_name: 'Spree::PaymentSession',
            foreign_key: :external_id,
            primary_key: :response_code

    validates :payment_method, presence: true
    validates :source, presence: true, if: :source_required?
    validates :response_code, uniqueness: { scope: [:order_id, :payment_method_id] }, allow_nil: true
    validate :payment_method_available_for_order, on: :create

    before_validation :validate_source

    after_initialize :set_amount, if: -> { new_record? && owner.present? && !amount_changed? }

    #
    # Callbacks
    before_create :assign_risk_codes_from_source
    # invalidate previously entered payments
    after_create :invalidate_old_payments
    after_create :create_eligible_credit_event
    # Every other change reaches the order through payment events, which the
    # order status subscriber answers. Destruction cannot: Payment is not
    # paranoid, so the row is gone by the time payment.deleted lands and its
    # payload carries no owner — nothing can lead the subscriber back to the
    # order, which still has to stop counting that money.
    after_destroy :recalculate_owner_totals

    attr_accessor :source_attributes, :request_env, :capture_on_dispatch
    attribute :skip_source_requirement, :boolean, default: false

    after_initialize :build_source

    validates :amount, numericality: true
    validate :amount_must_be_less_than_or_equal_to_max_amount, if: -> { new_record? || amount_changed? }

    delegate :store_credit?, to: :payment_method, allow_nil: true
    delegate :name,          to: :payment_method, allow_nil: true, prefix: true
    default_scope { order(:created_at) }

    scope :from_credit_card, -> { where(source_type: 'Spree::CreditCard') }
    # @deprecated use the status scopes / +where(status:)+ — removed in 6.1
    scope :with_state, ->(s) { where(status: s.to_s) }
    # "offset" is reserved by activerecord
    scope :offset_payment, -> { where("source_type = 'Spree::Payment' AND amount < 0 AND status = 'completed'") }

    # checkout/processing/pending/completed/failed/void scopes and predicates
    # come from has_status below.
    scope :incomplete, -> { where.not(status: 'completed') }

    scope :risky, -> { where("avs_response IN (?) OR (cvv_response_code IS NOT NULL and cvv_response_code != 'M') OR status = 'failed'", RISKY_AVS_CODES) }
    scope :valid, -> { where.not(status: INVALID_STATUSES) }

    scope :store_credits, -> { where(source_type: Spree::StoreCredit.to_s) }
    scope :not_store_credits, -> { where(arel_table[:source_type].not_eq(Spree::StoreCredit.to_s).or(arel_table[:source_type].eq(nil))) }

    self.whitelisted_ransackable_associations = %w[payment_method order source]
    ransack_alias :state, :status # @deprecated filter alias — removed in 6.1
    self.whitelisted_ransackable_attributes = %w[number amount status state response_code avs_response cvv_response_code cvv_response_message]

    # transaction_id is much easier to understand
    alias_attribute :transaction_id, :response_code

    delegate :currency, to: :owner

    money_methods :amount, :credit_allowed
    alias money display_amount # for compatibility with older versions of Spree

    # No state machine — transitions run inside Spree::Payments workflows and
    # Spree::Payment::Processing (docs/plans/6.0-service-workflows.md). The
    # `invalid` status deliberately generates no predicate or scope: `invalid?`
    # is ActiveModel's, use +has_invalid_status?+.
    include Spree::HasStatus
    has_status :checkout, :processing, :pending, :completed, :failed, :void, :invalid,
               default: :checkout

    # Status writes, called from the payments workflows and Processing. The
    # completed/voided events publish here — the one place the status changes —
    # replacing the machine's after_transition callbacks.
    # failed is deliberately claimable: a failure can be transient — a
    # gateway outage, a network timeout, our own error — and the retry is
    # simply running the workflow again on the same row. The row must be
    # reused, not replaced: response_code is unique per order, so a session
    # payment's intent can only ever live on one payment.
    CLAIMABLE_STATUSES = %w[checkout pending processing failed].freeze

    # Atomically claims the payment for gateway processing. Only a live or
    # retryable payment can be claimed, so a stale instance can never
    # resurrect a payment another writer already settled and drive the
    # gateway again.
    #
    # @return [Boolean] false when the payment completed concurrently — the
    #   caller's outcome already exists and the claim must be a no-op
    # @raise [Spree::Core::GatewayError] for a dead payment (void, invalid)
    def started_processing!
      if new_record?
        self.status = 'processing'
        save!
        return true
      end

      claimed = self.class.where(id: id, status: CLAIMABLE_STATUSES)
                          .update_all(status: 'processing', updated_at: Time.current) == 1
      if claimed
        self.status = 'processing'
        clear_attribute_changes(['status'])
        return true
      end

      fresh_status = self.class.where(id: id).pick(:status)
      return false if fresh_status == 'completed'

      raise Spree::Core::GatewayError, "Payment #{number} is #{fresh_status} and cannot be processed"
    end

    def pend!
      update!(status: 'pending')
    end

    def complete!
      update!(status: 'completed')
      publish_event('payment.completed')
      true
    end

    # The single void writer. A compare-and-swap rather than a plain save:
    # of two racing voids only the one whose update moves the row publishes
    # payment.voided, so the loser is an idempotent no-op. Callers that
    # already asked the gateway pass the authorization it returned.
    #
    # @param authorization [String, nil] written only when present — a
    #   successful void without one must not null the stored reference
    # @return [Boolean] false when the payment was already void
    def void!(authorization: nil)
      if new_record?
        self.status = 'void'
        self.response_code = authorization if authorization.present?
        save!
        publish_event('payment.voided')
        return true
      end

      updates = { status: 'void', updated_at: Time.current }
      updates[:response_code] = authorization if authorization.present?

      return false unless self.class.where(id: id).where.not(status: 'void').update_all(updates) == 1

      assign_attributes(updates.except(:updated_at))
      clear_attribute_changes(updates.except(:updated_at).keys)
      publish_event('payment.voided')
      true
    end

    def failure!
      update!(status: 'failed')
    end
    alias failure failure!

    def invalidate!
      update!(status: 'invalid')
    end

    # Guards preserved from the machine's transition graph, consulted by the
    # workflows before money moves.
    def can_complete?
      status.in?(%w[processing pending checkout])
    end

    def can_pend?
      status.in?(%w[checkout processing])
    end

    def can_void?
      status.in?(%w[pending processing completed checkout])
    end

    # @deprecated read +status+ — removed in 6.1
    def state
      Spree::Deprecation.warn('Spree::Payment#state is deprecated and will be removed in Spree 6.1. Use #status instead.')
      status
    end

    # @deprecated write +status+ — removed in 6.1
    def state=(value)
      Spree::Deprecation.warn('Spree::Payment#state= is deprecated and will be removed in Spree 6.1. Use #status= instead.')
      self.status = value
    end

    def source
      return super if payment_method.nil?
      return super unless payment_method.source_required?

      payment_method.payment_source_class.unscoped { super }
    end

    def max_amount
      return amount if owner.nil?

      amount_from_order = owner.total - owner.payment_total

      if payment_method&.store_credit?
        store_credits = owner.available_store_credits
        store_credits.any? ? [store_credits.first.amount_remaining, amount_from_order].min : amount_from_order
      else
        amount_from_order
      end
    end

    def amount=(amount)
      self[:amount] =
        case amount
        when String
          separator = I18n.t('number.currency.format.separator')
          number    = amount.delete("^0-9-#{separator}\.").tr(separator, '.')
          number.to_d if number.present?
        end || amount
    end

    def offsets_total
      offsets.sum(:amount)
    end

    def credit_allowed
      amount - (offsets_total.abs + refunds.sum(:amount))
    end

    def can_credit?
      credit_allowed > 0
    end

    # we shouldn't allow deleting payments via admin interface
    def can_be_deleted?
      false
    end

    # see https://github.com/spree/spree/issues/981
    def build_source
      return unless new_record?

      if source_attributes.present? && source.blank? && payment_method.try(:payment_source_class)
        self.source = if source_attributes[:id].present? && source_attributes[:id] != :new
                        payment_method.payment_source_class.find(source_attributes[:id])
                      else
                        payment_method.payment_source_class.new(source_attributes)
                      end

        if source.customer_id.present? && source.customer_id != owner&.customer_id
          self.source = nil
          return
        end

        source.payment_method_id = payment_method.id if source.respond_to?(:payment_method_id)
        source.customer_id = owner.customer_id if owner
      end
    end

    def actions
      return [] unless payment_source&.respond_to?(:actions)

      payment_source.actions.select { |action| !payment_source.respond_to?("can_#{action}?") || payment_source.send("can_#{action}?", self) }
    end

    def payment_source
      res = source.is_a?(Payment) ? source.source : source
      res || payment_method
    end

    def is_avs_risky?
      return false if avs_response.blank? || NON_RISKY_AVS_CODES.include?(avs_response)

      true
    end

    def is_cvv_risky?
      return false if cvv_response_code == 'M'
      return false if cvv_response_code.nil?
      return false if cvv_response_message.present?

      true
    end

    def gateway_dashboard_payment_url
      payment_method.try(:gateway_dashboard_payment_url, self)
    end

    def captured_amount
      capture_events.sum(:amount)
    end

    def uncaptured_amount
      amount - captured_amount
    end

    # Row work only — moves the uncaptured remainder onto a new pending
    # payment and shrinks this one to what was captured. The caller authorizes
    # the returned remainder at the gateway afterwards, outside any lock.
    #
    # @return [Spree::Payment, nil] the remainder payment, or nil when fully captured
    def split_uncaptured_amount
      return if uncaptured_amount <= 0

      remainder = owner.payments.create!(
        amount: uncaptured_amount,
        payment_method: payment_method,
        source: source,
        status: 'pending',
        capture_on_dispatch: true
      )
      update(amount: captured_amount)
      remainder
    end

    def editable?
      checkout? || pending?
    end

    def display_source_name
      return if source.blank?

      source_class = source.class
      source_class.respond_to?(:display_name) ? source_class.display_name : source_class.name.demodulize.split(/(?=[A-Z])/).join(' ')
    end

    def source_required?
      return false if skip_source_requirement

      payment_method&.source_required?
    end

    def add_gateway_processing_error(error_message)
      if has_custom_field?('gateway.processing_errors')
        errors = JSON.parse(get_custom_field('gateway.processing_errors').value)
        errors << { message: error_message }

        set_custom_field('gateway.processing_errors', errors.to_json)
      else
        set_custom_field('gateway.processing_errors', [{ message: error_message }].to_json)
      end
    end

    def gateway_processing_error_messages
      @gateway_processing_error_messages ||= begin
        errors = JSON.parse(get_custom_field('gateway.processing_errors')&.value || '[]')
        errors.map { |error| error['message'] }
      rescue JSON::ParserError
        []
      end
    end

    def has_invalid_status?
      INVALID_STATUSES.include?(status)
    end

    # @deprecated use {#has_invalid_status?} — removed in 6.1
    def has_invalid_state?
      Spree::Deprecation.warn('Spree::Payment#has_invalid_state? is deprecated and will be removed in Spree 6.1. Use #has_invalid_status? instead.')
      has_invalid_status?
    end

    # @return [Spree::Cart, Spree::Order, nil]
    def owner
      order || cart
    end

    # Bridge for legacy callers assigning +current_order+ (now a Spree::Cart)
    # to the order association — routes carts to the cart FK instead.
    def order=(record)
      if record.is_a?(Spree::Cart)
        self.cart = record
        super(nil)
      else
        super
      end
    end

    def profiles_supported?
      payment_method.respond_to?(:payment_profiles_supported?) && payment_method.payment_profiles_supported?
    end

    # Stores the payment source at the gateway for later off-session use.
    # Gateway I/O — creation flows that take raw card data call this
    # explicitly after the payment commits, on the same in-memory instance
    # (the card number never persists, and some gateways need it). Session
    # gateways store profile ids during source creation and never call this.
    def create_payment_profile
      # Don't attempt to create on bad payments.
      return if has_invalid_status?
      # Payment profile cannot be created without source
      return unless source
      # Imported payments shouldn't create a payment profile.
      # Imported is only available on Spree::CreditCard, non-credit card payments should not have this attribute.
      return if source.respond_to?(:imported) && source.imported

      payment_method.create_profile(self)
    rescue Spree::PaymentConnectionError => e
      gateway_error e
    end

    private

    # Session-created payments never pass through the gateway response path
    # that normally sets these codes, so the gateway gets asked at creation.
    # Codes already assigned (the response path runs before save) win.
    def assign_risk_codes_from_source
      return if source.blank?
      return if avs_response.present? && cvv_response_code.present?

      codes = payment_method&.risk_codes_for(source)
      return if codes.blank?

      self.avs_response ||= codes[:avs_response]
      self.cvv_response_code ||= codes[:cvv_response_code]
    end

    def exactly_one_owner
      errors.add(:base, Spree.t('errors.messages.exactly_one_of_cart_or_order')) unless [order, cart].compact.one?
    end

    def set_amount
      self.amount = owner.total - owner.payment_total
    end

    def amount_must_be_less_than_or_equal_to_max_amount
      errors.add(:amount, :greater_than_max_amount, max_amount: max_amount) if amount > max_amount
    end

    def validate_source
      if source && !source.valid?
        source.errors.map { |error| { field: error.attribute, message: error&.message } }.each do |err|
          next if err[:field].blank? || err[:message].blank?

          add_source_error(err[:field], err[:message])
        end
      end
      !errors.present?
    end

    def payment_method_available_for_order
      return if payment_method.blank?
      return if owner.blank?

      errors.add(:payment_method, :invalid) if !payment_method.available_for_order?(owner) || !payment_method.available_for_store?(owner.store)
    end

    def add_source_error(field, message)
      field_name = I18n.t("activerecord.attributes.#{source.class.to_s.underscore}.#{field}")
      errors.add(Spree.t(source.class.to_s.demodulize.underscore), "#{field_name} #{message}")
    end




    def recalculate_owner_totals
      return if owner.blank?

      owner.refresh_payment_total!
      owner.update_statuses! if owner.is_a?(Spree::Order) && owner.completed?
    end

    # @deprecated The order recomputes itself from payment events —
    #   Spree::Orders::UpdateStatuses writes statuses, the totals workflow
    #   writes payment_total. Removed in 7.0.
    def update_order
      Spree::Deprecation.warn('Spree::Payment#update_order is deprecated and will be removed in Spree 7.0. The order recomputes from payment events; call owner.recalculate_totals! to force it.')
      owner&.recalculate_totals!
    end

    def create_eligible_credit_event
      # When cancelling an order, a payment with the negative amount
      # of the payment total is created to refund the customer. That
      # payment has a source of itself (Spree::Payment) no matter the
      # type of payment getting refunded, hence the additional check
      # if the source is a store credit.
      return unless store_credit? && source.is_a?(Spree::StoreCredit)

      # creates the store credit event
      source.update!(action: Spree::StoreCredit::ELIGIBLE_ACTION,
                                action_amount: amount,
                                action_authorization_code: response_code)
    end

    def invalidate_old_payments
      # invalid payment or store_credit payment shouldn't invalidate other payment types
      return if has_invalid_status? || store_credit?

      owner.payments.with_state('checkout').where.not(id: id).each do |payment|
        payment.invalidate! unless payment.store_credit?
      end
    end
  end
end
