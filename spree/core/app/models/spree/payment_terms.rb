module Spree
  # What a buyer owes and when — the frozen answer to "how much now?".
  #
  # Resolved while the cart is live and copied onto the order at placement,
  # never re-derived afterwards: the deal was struck at that moment, and a
  # freight method whose deposit changes next month must not rewrite what
  # somebody already agreed to (docs/plans/6.0-6.1-b2b-payment-terms.md).
  #
  # A cart with no terms owes its whole total, which is every retail order.
  class PaymentTerms
    include ActiveModel::Model
    include ActiveModel::Attributes

    PREPAID = 'prepaid'.freeze
    DEPOSIT = 'deposit'.freeze
    # Extended by Enterprise with the invoice-shaped kinds (net terms); open
    # source collects before it ships, so it knows only these two.
    KINDS = [PREPAID, DEPOSIT].freeze

    attribute :kind, :string, default: PREPAID
    attribute :deposit_percentage, :decimal
    # What the merchant calls the rest — "Before shipping", "On arrival".
    # A label, never a date: real due dates are Enterprise terms.
    attribute :balance_due_label, :string
    # Where the percentage came from, so a merchant reading an old order can
    # tell a method default from something negotiated.
    attribute :source, :string
    # The total the deposit was struck against, stamped at placement. Without
    # it the deposit would be re-derived from a live total, and the forwarder's
    # freight charge landing later as a Fee would retroactively claim the buyer
    # agreed to a larger deposit than they paid.
    attribute :base_total, :decimal

    class << self
      # Reads the terms a delivery rate's method declares. The only source in
      # open source; Enterprise layers company and quote overrides in front.
      #
      # @param delivery_rate [Spree::DeliveryRate, nil]
      # @return [Spree::PaymentTerms, nil]
      def from_delivery_rate(delivery_rate)
        method = delivery_rate&.delivery_method
        return if method.nil?

        provider = method.rate_provider_instance
        return unless provider.respond_to?(:deposit_percentage)

        percentage = provider.deposit_percentage
        return unless percentage&.positive?

        new(
          kind: DEPOSIT,
          deposit_percentage: percentage,
          balance_due_label: provider.try(:balance_due_label),
          source: 'delivery_method'
        )
      end

      # @param payload [Hash, nil]
      # @return [Spree::PaymentTerms, nil]
      def from_snapshot(payload)
        return if payload.blank?

        payload = payload.with_indifferent_access
        new(payload.slice(*attribute_names.map(&:to_sym)))
      end
    end

    # @return [Boolean]
    def deposit?
      kind == DEPOSIT && deposit_percentage.to_d.positive?
    end

    # The part of a total due at checkout.
    #
    # Rounded UP to the currency's own smallest unit, so a buyer is never
    # asked for less than the percentage agreed and the balance absorbs the
    # remainder — the two always sum back to the total exactly
    # (decisions.md 2026-09-05).
    #
    # Once placed, the deposit is measured against the total it was struck
    # against, never the live one — a freight charge recorded afterwards
    # raises what is owed, not what was already agreed and paid.
    #
    # @param total [BigDecimal]
    # @param currency [String]
    # @return [BigDecimal]
    def amount_due_now(total, currency:)
      total = (base_total || total).to_d
      return total unless deposit?

      unit = smallest_unit(currency)
      raw = total * deposit_percentage.to_d / 100

      [(raw / unit).ceil * unit, total].min
    end

    def as_json(*)
      {
        'kind' => kind,
        'deposit_percentage' => deposit_percentage&.to_s,
        'balance_due_label' => balance_due_label,
        'source' => source,
        'base_total' => base_total&.to_s
      }
    end

    private

    # Zero-decimal currencies exist, so the step is the currency's own, never
    # a hardcoded 0.01.
    def smallest_unit(currency)
      exponent = ::Money::Currency.find(currency)&.exponent || 2

      BigDecimal(1) / (10**exponent)
    end
  end
end
