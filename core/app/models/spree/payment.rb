module Spree
  class Payment < Spree::Base
    include Spree::Core::NumberGenerator.new(prefix: 'P', letters: true, length: 7)

    extend FriendlyId
    friendly_id :number, slug_column: :number, use: :slugged

    include Spree::Payment::Processing

    NON_RISKY_AVS_CODES = ['B', 'D', 'H', 'J', 'M', 'Q', 'T', 'V', 'X', 'Y'].freeze
    RISKY_AVS_CODES     = ['A', 'C', 'E', 'F', 'G', 'I', 'K', 'L', 'N', 'O', 'P', 'R', 'S', 'U', 'W', 'Z'].freeze

    with_options inverse_of: :payments do
      belongs_to :order, class_name: 'Spree::Order', touch: true
      belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    end
    belongs_to :source, polymorphic: true

    has_many :offsets, -> { offset_payment }, class_name: "Spree::Payment", foreign_key: :source_id
    has_many :log_entries, as: :source
    has_many :state_changes, as: :stateful
    has_many :capture_events, class_name: 'Spree::PaymentCaptureEvent'
    has_many :refunds, inverse_of: :payment

    validates :payment_method, presence: true
    before_validation :validate_source

    after_save :create_payment_profile, if: :profiles_supported?

    # update the order totals, etc.
    after_save :update_order

    # invalidate previously entered payments
    after_create :invalidate_old_payments

    attr_accessor :source_attributes, :request_env

    after_initialize :build_source

    validates :amount, numericality: true

    default_scope { order(:created_at) }

    scope :from_credit_card, -> { where(source_type: 'Spree::CreditCard') }
    scope :with_state, ->(s) { where(state: s.to_s) }
    # "offset" is reserved by activerecord
    scope :offset_payment, -> { where("source_type = 'Spree::Payment' AND amount < 0 AND state = 'completed'") }

    scope :checkout, -> { with_state('checkout') }
    scope :completed, -> { with_state('completed') }
    scope :pending, -> { with_state('pending') }
    scope :processing, -> { with_state('processing') }
    scope :failed, -> { with_state('failed') }

    scope :risky, -> { where("avs_response IN (?) OR (cvv_response_code IS NOT NULL and cvv_response_code != 'M') OR state = 'failed'", RISKY_AVS_CODES) }
    scope :valid, -> { where.not(state: %w(failed invalid)) }

    # transaction_id is much easier to understand
    def transaction_id
      response_code
    end

    # order state machine (see http://github.com/pluginaweek/state_machine/tree/master for details)
    state_machine initial: :checkout do
      # With card payments, happens before purchase or authorization happens
      #
      # Setting it after creating a profile and authorizing a full amount will
      # prevent the payment from being authorized again once Order transitions
      # to complete
      event :started_processing do
        transition from: [:checkout, :pending, :completed, :processing], to: :processing
      end
      # When processing during checkout fails
      event :failure do
        transition from: [:pending, :processing], to: :failed
      end
      # With card payments this represents authorizing the payment
      event :pend do
        transition from: [:checkout, :processing], to: :pending
      end
      # With card payments this represents completing a purchase or capture transaction
      event :complete do
        transition from: [:processing, :pending, :checkout], to: :completed
      end
      event :void do
        transition from: [:pending, :processing, :completed, :checkout], to: :void
      end
      # when the card brand isnt supported
      event :invalidate do
        transition from: [:checkout], to: :invalid
      end

      after_transition do |payment, transition|
        payment.state_changes.create!(
          previous_state: transition.from,
          next_state:     transition.to,
          name:           'payment',
        )
      end
    end

    def currency
      order.currency
    end

    def money
      Spree::Money.new(amount, { currency: currency })
    end
    alias display_amount money

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
      offsets.pluck(:amount).sum
    end

    def credit_allowed
      amount - (offsets_total.abs + refunds.sum(:amount))
    end

    def can_credit?
      credit_allowed > 0
    end

    # see https://github.com/spree/spree/issues/981
    def build_source
      return unless new_record?
      if source_attributes.present? && source.blank? && payment_method.try(:payment_source_class)
        self.source = payment_method.payment_source_class.new(source_attributes)
        self.source.payment_method_id = payment_method.id
        self.source.user_id = self.order.user_id if self.order
      end
    end

    def actions
      return [] unless payment_source and payment_source.respond_to? :actions
      payment_source.actions.select { |action| !payment_source.respond_to?("can_#{action}?") or payment_source.send("can_#{action}?", self) }
    end

    def payment_source
      res = source.is_a?(Payment) ? source.source : source
      res || payment_method
    end

    def is_avs_risky?
      return false if avs_response.blank? || NON_RISKY_AVS_CODES.include?(avs_response)
      return true
    end

    def is_cvv_risky?
      return false if cvv_response_code == "M"
      return false if cvv_response_code.nil?
      return false if cvv_response_message.present?
      return true
    end

    def captured_amount
      capture_events.sum(:amount)
    end

    def uncaptured_amount
      amount - captured_amount
    end

    def editable?
      checkout? || pending?
    end

    private

      def validate_source
        if source && !source.valid?
          source.errors.each do |field, error|
            field_name = I18n.t("activerecord.attributes.#{source.class.to_s.underscore}.#{field}")
            self.errors.add(Spree.t(source.class.to_s.demodulize.underscore), "#{field_name} #{error}")
          end
        end
        return !errors.present?
      end

      def profiles_supported?
        payment_method.respond_to?(:payment_profiles_supported?) && payment_method.payment_profiles_supported?
      end

      def create_payment_profile
        # Don't attempt to create on bad payments.
        return if %w(invalid failed).include?(state)
        # Payment profile cannot be created without source
        return unless source
        # Imported payments shouldn't create a payment profile.
        return if source.imported

        payment_method.create_profile(self)
      rescue ActiveMerchant::ConnectionError => e
        gateway_error e
      end

      def invalidate_old_payments
        if state != 'invalid' and state != 'failed'
          order.payments.with_state('checkout').where("id != ?", self.id).each do |payment|
            payment.invalidate!
          end
        end
      end

      def split_uncaptured_amount
        if uncaptured_amount > 0
          order.payments.create! amount: uncaptured_amount,
                                 avs_response: avs_response,
                                 cvv_response_code: cvv_response_code,
                                 cvv_response_message: cvv_response_message,
                                 payment_method: payment_method,
                                 response_code: response_code,
                                 source: source,
                                 state: 'pending'
          update_attributes(amount: captured_amount)
        end
      end

      def update_order
        if completed? || void?
          order.updater.update_payment_total
        end

        if order.completed?
          order.updater.update_payment_state
          order.updater.update_shipments
          order.updater.update_shipment_state
        end

        if self.completed? || order.completed?
          order.persist_totals
        end
      end

  end
end
