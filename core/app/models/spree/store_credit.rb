module Spree
  class StoreCredit < Spree::Base
    acts_as_paranoid

    VOID_ACTION       = 'void'.freeze
    CANCEL_ACTION     = 'cancel'.freeze
    CREDIT_ACTION     = 'credit'.freeze
    CAPTURE_ACTION    = 'capture'.freeze
    ELIGIBLE_ACTION   = 'eligible'.freeze
    AUTHORIZE_ACTION  = 'authorize'.freeze
    ALLOCATION_ACTION = 'allocation'.freeze

    DEFAULT_CREATED_BY_EMAIL = 'spree@example.com'.freeze

    belongs_to :user, class_name: Spree.user_class.to_s, foreign_key: 'user_id'
    belongs_to :category, class_name: 'Spree::StoreCreditCategory'
    belongs_to :created_by, class_name: Spree.user_class.to_s, foreign_key: 'created_by_id'
    belongs_to :credit_type, class_name: 'Spree::StoreCreditType', foreign_key: 'type_id'
    has_many :store_credit_events

    validates :user, :category, :credit_type, :created_by, :currency, presence: true
    validates :amount, numericality: { greater_than: 0 }
    validates :amount_used, numericality: { greater_than_or_equal_to: 0 }
    validate :amount_used_less_than_or_equal_to_amount
    validate :amount_authorized_less_than_or_equal_to_amount

    delegate :name, to: :category, prefix: true
    delegate :email, to: :created_by, prefix: true

    scope :order_by_priority, -> { includes(:credit_type).order('spree_store_credit_types.priority ASC') }

    before_validation :associate_credit_type
    after_save :store_event
    before_destroy :validate_no_amount_used

    attr_accessor :action, :action_amount, :action_originator, :action_authorization_code

    extend Spree::DisplayMoney
    money_methods :amount, :amount_used

    def amount_remaining
      amount - amount_used - amount_authorized
    end

    def authorize(amount, order_currency, options = {})
      authorization_code = options[:action_authorization_code]
      if authorization_code
        if store_credit_events.find_by(action: AUTHORIZE_ACTION, authorization_code: authorization_code)
          # Don't authorize again on capture
          return true
        end
      else
        authorization_code = generate_authorization_code
      end
      if validate_authorization(amount, order_currency)
        update!(
          action: AUTHORIZE_ACTION,
          action_amount: amount,
          action_originator: options[:action_originator],
          action_authorization_code: authorization_code,
          amount_authorized: amount_authorized + amount
        )
        authorization_code
      else
        errors.add(:base, Spree.t('store_credit_payment_method.insufficient_authorized_amount'))
        false
      end
    end

    def validate_authorization(amount, order_currency)
      if amount_remaining.to_d < amount.to_d
        errors.add(:base, Spree.t('store_credit_payment_method.insufficient_funds'))
      elsif currency != order_currency
        errors.add(:base, Spree.t('store_credit_payment_method.currency_mismatch'))
      end
      errors.blank?
    end

    def capture(amount, authorization_code, order_currency, options = {})
      return false unless authorize(amount, order_currency, action_authorization_code: authorization_code)

      if amount <= amount_authorized
        if currency != order_currency
          errors.add(:base, Spree.t('store_credit_payment_method.currency_mismatch'))
          false
        else
          update!(
            action: CAPTURE_ACTION,
            action_amount: amount,
            action_originator: options[:action_originator],
            action_authorization_code: authorization_code,
            amount_used: amount_used + amount,
            amount_authorized: amount_authorized - amount
          )
          authorization_code
        end
      else
        errors.add(:base, Spree.t('store_credit_payment_method.insufficient_authorized_amount'))
        false
      end
    end

    def void(authorization_code, options = {})
      if auth_event = store_credit_events.find_by(action: AUTHORIZE_ACTION, authorization_code: authorization_code)
        update!(
          action: VOID_ACTION,
          action_amount: auth_event.amount,
          action_authorization_code: authorization_code,
          action_originator: options[:action_originator],
          amount_authorized: amount_authorized - auth_event.amount
        )
        true
      else
        errors.add(:base, Spree.t('store_credit_payment_method.unable_to_void', auth_code: authorization_code))
        false
      end
    end

    def credit(amount, authorization_code, order_currency, options = {})
      # Find the amount related to this authorization_code in order to add the store credit back
      capture_event = store_credit_events.find_by(action: CAPTURE_ACTION, authorization_code: authorization_code)

      if currency != order_currency # sanity check to make sure the order currency hasn't changed since the auth
        errors.add(:base, Spree.t('store_credit_payment_method.currency_mismatch'))
        false
      elsif capture_event && amount <= capture_event.amount
        action_attributes = {
          action: CREDIT_ACTION,
          action_amount: amount,
          action_originator: options[:action_originator],
          action_authorization_code: authorization_code
        }
        create_credit_record(amount, action_attributes)
        true
      else
        errors.add(:base, Spree.t('store_credit_payment_method.unable_to_credit', auth_code: authorization_code))
        false
      end
    end

    def actions
      [CAPTURE_ACTION, VOID_ACTION, CREDIT_ACTION]
    end

    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    def can_void?(payment)
      payment.pending? || (payment.checkout? && !payment.order.completed?)
    end

    def can_credit?(payment)
      payment.completed? && payment.credit_allowed > 0
    end

    def generate_authorization_code
      "#{id}-SC-#{Time.now.utc.strftime('%Y%m%d%H%M%S%6N')}"
    end

    class << self
      def default_created_by
        Spree.user_class.find_by(email: DEFAULT_CREATED_BY_EMAIL)
      end
    end

    private

    def create_credit_record(amount, action_attributes = {})
      # Setting credit_to_new_allocation to true will create a new allocation anytime #credit is called
      # If it is not set, it will update the store credit's amount in place
      credit = if Spree::Config.credit_to_new_allocation
                 Spree::StoreCredit.new(create_credit_record_params(amount))
               else
                 self.amount_used = amount_used - amount
                 self
               end

      credit.assign_attributes(action_attributes)
      credit.save!
    end

    def create_credit_record_params(amount)
      {
        amount: amount,
        user_id: user_id,
        category_id: category_id,
        created_by_id: created_by_id,
        currency: currency,
        type_id: type_id,
        memo: credit_allocation_memo
      }
    end

    def credit_allocation_memo
      "This is a credit from store credit ID #{id}"
    end

    def store_event
      return unless saved_change_to_amount? ||
        saved_change_to_amount_used? ||
        saved_change_to_amount_authorized? ||
        action == ELIGIBLE_ACTION

      event = if action
                store_credit_events.build(action: action)
              else
                store_credit_events.where(action: ALLOCATION_ACTION).first_or_initialize
              end

      event.update!(
        amount: action_amount || amount,
        authorization_code: action_authorization_code || event.authorization_code || generate_authorization_code,
        user_total_amount: user.total_available_store_credit,
        originator: action_originator
      )
    end

    def amount_used_less_than_or_equal_to_amount
      return true if amount_used.nil?

      if amount_used > amount
        errors.add(:amount_used, :cannot_be_greater_than_amount)
        false
      end
    end

    def amount_authorized_less_than_or_equal_to_amount
      if (amount_used + amount_authorized) > amount
        errors.add(:amount_authorized, :exceeds_total_credits)
        false
      end
    end

    def validate_no_amount_used
      if amount_used > 0
        errors.add(:amount_used, :greater_than_zero_restrict_delete)
        throw(:abort)
      end
    end

    def associate_credit_type
      unless type_id
        credit_type_name = category.try(:non_expiring?) ? 'Non-expiring' : 'Expiring'
        self.credit_type = Spree::StoreCreditType.find_by(name: credit_type_name)
      end
    end
  end
end
