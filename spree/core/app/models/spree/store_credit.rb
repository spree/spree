module Spree
  class StoreCredit < Spree.base_class
    has_prefix_id :credit

    include Spree::SingleStoreResource
    include Spree::ActedBy
    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::CanonicalDecimals

    canonical_decimals :amount

    publishes_lifecycle_events

    acts_as_paranoid

    VOID_ACTION       = 'void'.freeze
    CANCEL_ACTION     = 'cancel'.freeze
    CREDIT_ACTION     = 'credit'.freeze
    CAPTURE_ACTION    = 'capture'.freeze
    ELIGIBLE_ACTION   = 'eligible'.freeze
    AUTHORIZE_ACTION  = 'authorize'.freeze
    ALLOCATION_ACTION = 'allocation'.freeze

    # A gift card applied to a guest cart issues store credit with no customer
    # to attach it to.
    belongs_to :customer, class_name: "::#{Spree.customer_class}", optional: true
    include Spree::DeprecatedCustomerAlias
    acted_by :created_by
    belongs_to :originator, polymorphic: true, optional: true
    belongs_to :refunded_order, class_name: 'Spree::Order', optional: true,
                                inverse_of: :store_credit_refunds

    has_many :store_credit_events, class_name: 'Spree::StoreCreditEvent'
    # The refund rows that record this credit as money an order gave back —
    # one per payment it was drawn against. Kept when the credit is withdrawn,
    # and marked failed instead (see #withdraw_refunds).
    has_many :refunds, class_name: 'Spree::Refund', inverse_of: :store_credit, dependent: nil
    has_many :payments, as: :source, class_name: 'Spree::Payment'
    has_many :orders, through: :payments, class_name: 'Spree::Order'

    validates :currency, presence: true
    validates :amount, numericality: { greater_than: 0 }
    validates :amount_used, numericality: { greater_than_or_equal_to: 0 }
    validate :amount_used_less_than_or_equal_to_amount
    validate :amount_authorized_less_than_or_equal_to_amount
    # Its refund rows record the amount as given back, so changing it would
    # leave the order's refunds saying something the credit no longer does.
    validate :amount_unchanged_once_refunded, on: :update

    # Redemption order: the oldest credit is spent first.
    scope :oldest_first, -> { order(:created_at, :id) }
    # @deprecated Removed in Spree 6.3 — store credit types are gone; use {.oldest_first}.
    scope :order_by_priority, lambda {
      Spree::Deprecation.warn('Spree::StoreCredit.order_by_priority is deprecated and will be removed in Spree 6.3. Use .oldest_first instead.')
      oldest_first
    }

    scope :not_authorized, -> { where(amount_authorized: 0) }
    scope :not_used, -> { where("#{Spree::StoreCredit.table_name}.amount_used < #{Spree::StoreCredit.table_name}.amount") }
    # Spendable right now, for the checkout path: a credit with any amount
    # authorized is mid-payment and must not be authorized again, even though
    # part of it may still be unspent. Narrower than {.unspent} on purpose.
    scope :available, -> { not_authorized.not_used }

    # Money the store still owes: whatever is neither spent nor committed to an
    # in-flight authorization. A credit of 100 with 10 authorized has 90 left
    # and belongs here, which is what separates this from {.available}.
    scope :unspent, lambda {
      table = arel_table
      committed = Arel::Nodes::Grouping.new(table[:amount_used] + table[:amount_authorized])
      where(committed.lt(table[:amount]))
    }

    # The complement of {.unspent}: nothing left to draw on.
    scope :exhausted, lambda {
      table = arel_table
      committed = Arel::Nodes::Grouping.new(table[:amount_used] + table[:amount_authorized])
      where(committed.gteq(table[:amount]))
    }
    scope :with_gift_card, -> { where(originator_type: 'Spree::GiftCard') }
    scope :without_gift_card, -> { where(originator_type: [nil, '']).or(where.not(originator_type: 'Spree::GiftCard')) }

    # What a merchant filters the credit list by: money still owed, or money
    # already spent. One ransackable scope with two named states rather than
    # two bare scopes, so the filter control offers a choice instead of a
    # checkbox whose unticked state means "no filter".
    #
    # Splat, not a defaulted argument: Ransack splats an array predicate, and
    # asking for both sides is no constraint at all. See Spree::Base.ransack_flag.
    scope :outstanding, ->(*values) {
      case Spree::Base.ransack_flag(*values)
      when true then unspent
      when false then exhausted
      else all
      end
    }

    # Whether the credit came from redeeming a gift card, as opposed to a
    # return, an exchange, a claim or an admin issuing it by hand.
    scope :from_gift_card, ->(*values) {
      case Spree::Base.ransack_flag(*values)
      when true then with_gift_card
      when false then without_gift_card
      else all
      end
    }

    before_destroy :lock_for_destroy
    before_destroy :validate_no_amount_used
    before_destroy :withdraw_refunds
    after_save :store_event
    after_destroy :refresh_withdrawn_orders
    after_commit :announce_withdrawn_refunds, on: :destroy

    attr_accessor :action, :action_amount, :action_originator, :action_authorization_code

    extend Spree::DisplayMoney
    money_methods :amount, :amount_used, :amount_remaining, :amount_authorized

    self.whitelisted_ransackable_attributes = %w[customer_id created_by_id amount currency memo]
    search_by :memo
    self.whitelisted_ransackable_associations = %w[customer]
    self.whitelisted_ransackable_scopes = %w[outstanding from_gift_card]
    self.ransackable_scope_types = %w[outstanding from_gift_card].index_with('boolean')
    # Staff notes and who issued the credit are back-office data.
    self.private_ransackable_attributes = { store: %w[memo created_by_id] }

    # Two-state scopes: see Spree::Base.ransack_flag? for why the cast is
    # opted out of here and done inside each scope instead.
    def self.ransackable_scopes_skip_sanitize_args
      super | %w[outstanding from_gift_card]
    end

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
        errors.add(:base, :insufficient_authorized_amount, message: I18n.t('spree.store_credit_payment_method.insufficient_authorized_amount'))
        false
      end
    end

    def validate_authorization(amount, order_currency)
      if BigDecimal(amount_remaining, 3) < BigDecimal(amount, 3)
        errors.add(:base, :insufficient_funds, message: I18n.t('spree.store_credit_payment_method.insufficient_funds'))
      elsif currency != order_currency
        errors.add(:base, :currency_mismatch, message: I18n.t('spree.store_credit_payment_method.currency_mismatch'))
      end
      errors.blank?
    end

    def capture(amount, authorization_code, order_currency, options = {})
      return false unless authorize(amount, order_currency, action_authorization_code: authorization_code)

      if amount <= amount_authorized
        if currency != order_currency
          errors.add(:base, :currency_mismatch, message: I18n.t('spree.store_credit_payment_method.currency_mismatch'))
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
        errors.add(:base, :insufficient_authorized_amount, message: I18n.t('spree.store_credit_payment_method.insufficient_authorized_amount'))
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
        errors.add(:base, :unable_to_void, auth_code: authorization_code,
                   message: I18n.t('spree.store_credit_payment_method.unable_to_void', auth_code: authorization_code))
        false
      end
    end

    def credit(amount, authorization_code, order_currency, options = {})
      # Find the amount related to this authorization_code in order to add the store credit back
      capture_event = store_credit_events.find_by(action: CAPTURE_ACTION, authorization_code: authorization_code)

      if currency != order_currency # sanity check to make sure the order currency hasn't changed since the auth
        errors.add(:base, :currency_mismatch, message: I18n.t('spree.store_credit_payment_method.currency_mismatch'))
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
        errors.add(:base, :unable_to_credit, auth_code: authorization_code,
                   message: I18n.t('spree.store_credit_payment_method.unable_to_credit', auth_code: authorization_code))
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

    # Whether the store still owes anything on this credit. The record-level
    # twin of the `unspent` scope, and the two must agree: the list filters on
    # the scope and the row renders this, so a client deriving one from the
    # money columns itself would drift from the filter that hides it.
    #
    # @return [Boolean]
    def outstanding?
      amount_used + amount_authorized < amount
    end

    def editable?
      amount_used.zero? && amount_authorized.zero?
    end

    def can_be_deleted?
      amount_used.zero? && amount_authorized.zero?
    end

    def generate_authorization_code
      "#{id}-SC-#{Time.now.utc.strftime('%Y%m%d%H%M%S%6N')}"
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
        customer_id: customer_id,
        created_by_id: created_by_id,
        created_by_type: created_by_type,
        currency: currency,
        memo: credit_allocation_memo,
        store: store
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
        user_total_amount: customer&.total_available_store_credit || 0,
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

    def amount_unchanged_once_refunded
      errors.add(:amount, :refunded) if amount_changed? && refunds.exists?
    end

    # Also refused while part of it is authorized on a cart: that cart could
    # still capture it once deleted.
    def validate_no_amount_used
      if amount_used > 0
        errors.add(:amount_used, :greater_than_zero_restrict_delete)
        throw(:abort)
      elsif amount_authorized.positive?
        errors.add(:amount_authorized, :greater_than_zero_restrict_delete)
        throw(:abort)
      end
    end

    # Takes the locks the destroy needs before anything is read: the orders
    # its refunds were recorded against, in id order, then the credit itself,
    # re-read. Refund creation and the backfill lock the order before they
    # write a refund for the credit, and an authorization locks the credit,
    # so neither can land between the guard below and the withdrawal. The
    # order-then-credit order matches theirs, so the two cannot deadlock.
    def lock_for_destroy
      order_ids = (refunds.not_failed.distinct.pluck(:order_id) + [refunded_order_id]).compact.uniq.sort
      @withdrawn_orders = Spree::Order.where(id: order_ids).order(:id).lock.to_a
      # The re-read clears how the destroy was reached; keep it.
      by_association = destroyed_by_association
      lock!
      self.destroyed_by_association = by_association
    end

    # A credit withdrawn before it was spent gave the order nothing back after
    # all, so the refunds that recorded it fail — in the same transaction, so
    # they cannot be left standing. Not when the credit goes with its
    # customer: that money was given back, and the refunds stand.
    def withdraw_refunds
      return if destroyed_by_association

      @withdrawn_refunds = refunds.not_failed.lock.to_a
      @withdrawn_refunds.each do |refund|
        refund.update!(status: 'failed', failure_reason: I18n.t('spree.store_credit_withdrawn'))
      end
    end

    # Once the credit is gone, still inside the destroy's transaction: before
    # then the order would count it as credit given back that no refund
    # records.
    def refresh_withdrawn_orders
      Array(@withdrawn_orders).each { |order| refresh_refunded_order(order) } unless destroyed_by_association
      @withdrawn_orders = nil
    end

    # What refund.failed would move, moved here so it cannot be skipped: each
    # share's refunded figure — under the share's lock, from a locking read,
    # so a refund landing on it meanwhile is not overwritten — and the
    # order's payment total and statuses.
    def refresh_refunded_order(order)
      order.payment_splits.order(:id).each do |split|
        split.with_lock do
          refunded = Spree::Refund.completed_or_unset.where(payment_id: split.payment_id, order_id: order.id).
                     lock.pluck(:amount).sum(0.to_d)
          split.update!(refunded_amount: refunded)
        end
      end
      order.refresh_payment_total!
      order.update_statuses!
    end

    # Announced once committed, so the split share and the order's payment
    # total and status follow, as for any refund that failed.
    def announce_withdrawn_refunds
      Array(@withdrawn_refunds).each { |refund| refund.publish_event('refund.failed') }
      @withdrawn_refunds = nil
    end
  end
end
