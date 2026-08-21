# frozen_string_literal: true

module Spree
  # N orders placed together as one customer checkout.
  #
  # Deliberately domain-neutral. Multi-vendor is its first consumer — a mixed
  # cart splits into one order per seller — but the same container serves
  # split-by-fulfillment-location, split-by-availability and B2B
  # split-by-company-location, none of which involve a seller. The seller
  # therefore lives on the child order and never here
  # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 8).
  #
  # The group owns what the customer experienced once: the payment they made,
  # the addresses they entered, the contact email. Children own what varies per
  # seller: line items, fulfillments, totals, and their own money lines.
  #
  # Status is derived across the children rather than stored, because a column
  # would be a second source of truth for something the children already
  # answer, and it would need re-writing on every child transition.
  class OrderGroup < Spree.base_class
    has_prefix_id :ogrp

    include Spree::Metadata
    include Spree::SingleStoreResource
    # The same number rules an order follows — the group's number seeds its
    # children's, so a difference in case or length would show up between a
    # group and the orders named after it.
    include Spree::NumberIdentifier
    # A payment is validated and sized against whatever it was made against, so
    # the group has to answer the same store-credit questions a cart or an
    # order does — it is what the customer paid.
    include Spree::Purchase::StoreCredits

    # Shares the order counter rather than running one of its own: a group and
    # an order are both things a customer calls "my order", and two counters
    # behind one `R` prefix would eventually issue the same string for both.
    # In practice the split copies the number from the order it adopts, so this
    # only fires for a group created some other way.
    has_spree_number prefix: 'R', key: :order

    publishes_lifecycle_events

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :customer, class_name: "::#{Spree.customer_class}", optional: true
    # The cart this group was completed from — unique, and the replay key that
    # makes a retried completion return this group instead of building another.
    belongs_to :cart, class_name: 'Spree::Cart', optional: true, inverse_of: :order_group

    # restrict_with_error, never cascade: these are completed orders, and a
    # container going away is not a reason to lose them.
    has_many :orders, class_name: 'Spree::Order', inverse_of: :order_group, dependent: :restrict_with_error
    has_many :payments, class_name: 'Spree::Payment', inverse_of: :order_group, dependent: :restrict_with_error
    has_many :payment_splits, through: :payments, class_name: 'Spree::PaymentSplit', source: :payment_splits

    # Brings the ship/bill pair with the shipping_address/billing_address
    # aliases every other purchase surface reads them by.
    #
    # Only the associations and aliases apply here. The concern's checkout
    # helpers — shipping_address_required?, assign_default_addresses! — reach
    # for line items, fulfillments and digital goods, none of which a group
    # has: they belong to its children, which answer those questions for
    # themselves. A group's addresses are copies made when the checkout
    # divided, so nothing asks it to work them out.
    include Spree::Purchase::Addresses
    # What a marketplace asks about a group. Kept out of the class itself so
    # this stays the neutral primitive its other consumers need.
    include Spree::Marketplace::OrderGroup

    #
    # Validations
    #
    validates :currency, presence: true

    #
    # Scopes
    #
    self.whitelisted_ransackable_attributes = %w[number email currency created_at]
    self.whitelisted_ransackable_associations = %w[orders customer]

    extend Spree::DisplayMoney
    money_methods :total, :item_total

    # What the customer was charged for the whole checkout, and what it was
    # charged for — the sums of what each child independently computed. Never
    # prorated downward: the children are the record, these are the roll-up,
    # and a gateway asking what it is charging for gets the whole basket
    # because the whole basket is what the one charge covers.
    #
    # Summed in Ruby rather than by SQL aggregate: anything reading these has
    # the children loaded already (a serializer renders them, a gateway call
    # reads four of these in a row), and an aggregate per figure would issue a
    # query each time even against rows sitting in memory.
    ROLLED_UP_TOTALS = %i[
      total item_total delivery_total additional_tax_total included_tax_total
      discount_total fee_total
    ].freeze

    ROLLED_UP_TOTALS.each do |figure|
      define_method(figure) do
        rolled_up_totals[figure]
      end
    end

    alias ship_total delivery_total

    # Where the checkout was made from, carried on the children because they
    # are what the checkout produced.
    #
    # @return [String, nil]
    def last_ip_address
      orders.first&.last_ip_address
    end

    # @return [String, nil] the group's fulfillment position, in the same
    #   vocabulary a single order uses, rolled up across children
    def fulfillment_status
      roll_up(orders.map(&:fulfillment_status)) do |statuses|
        # Canceled siblings do not make the group canceled — a recalled parcel
        # does not describe the purchase while another is still coming.
        live = statuses - ['canceled']
        next 'canceled' if live.empty?

        live.one? ? live.first : 'partial'
      end
    end

    # The payment is shared, but each child reports its own share of it — so
    # this rolls those up rather than reading the payment, and a checkout with
    # one seller shipped and another not says so.
    #
    # @return [String, nil]
    def payment_status
      roll_up(orders.map(&:payment_status))
    end

    #
    # The payment-owner contract. A payment reads these off whatever it was
    # made against — the group answers them by rolling up its children rather
    # than from columns of its own, since the children are the record of what
    # was sold and this is only the container they were bought in.
    #

    # @return [BigDecimal] completed payments on this group, less their refunds
    def payment_total
      @payment_total ||= begin
        settled = payments.select { |payment| payment.status == 'completed' }
        settled.sum(&:amount) - Spree::Refund.where(payment_id: settled.map(&:id)).sum(:amount)
      end
    end

    # Nothing to persist — payment_total is derived here — but the payment path
    # calls this after settling, so it must exist, and it must forget what it
    # last worked out or a settled payment would go unnoticed.
    #
    # @return [BigDecimal]
    def refresh_payment_total!
      forget_derived_money
      payment_total
    end

    # Drops the memoized roll-ups. Money moves through the children and their
    # payments, not through this record, so nothing here is dirtied by a write
    # that changes what it reports.
    def forget_derived_money
      @rolled_up_totals = nil
      @payment_total = nil
    end

    # @return [BigDecimal] still to collect across the whole checkout
    def outstanding_balance
      total - payment_total
    end

    # @return [Boolean]
    def paid?
      total.positive? && payment_total >= total
    end

    # A group only ever exists because a checkout finished, so it is completed
    # by construction. Store-credit reporting asks, to tell what was applied
    # from what could still be.
    #
    # @return [Boolean]
    def completed?
      true
    end

    def number_store
      store
    end

    private

    # One pass over the children for every figure, so reading four of them
    # costs what reading one does.
    def rolled_up_totals
      @rolled_up_totals ||= orders.to_a.each_with_object(Hash.new(BigDecimal(0))) do |order, totals|
        ROLLED_UP_TOTALS.each { |figure| totals[figure] += order.public_send(figure).to_d }
      end
    end

    # Collapses the children's answers into one word: nothing to say, the one
    # they agree on, or a mixture. What a mixture means is the caller's, since
    # only it knows which of its values absorb the others.
    #
    # @return [String, nil]
    def roll_up(statuses)
      statuses = statuses.compact.uniq
      return if statuses.empty?
      return statuses.first if statuses.one?

      block_given? ? yield(statuses) : 'partial'
    end
  end
end
