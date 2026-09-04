module SpreeAvalara
  # A return as AvaTax's ReturnInvoice: the returned lines at negative amounts,
  # keyed to the return so filing it twice adjusts one document.
  #
  # Deliberately line-level rather than the percentage RefundTransactionModel —
  # the contract credits the lines that came back, not a share of the order.
  class RefundPresenter
    # @param order [Spree::Order]
    # @param integration [SpreeAvalara::Integration]
    # @param return_items [Array<Spree::ReturnLineItem>]
    # @param amount [BigDecimal, nil] what the customer was actually refunded;
    #   nil means the returned lines' full worth
    # @param tax_date [Time, nil] the original supply date
    # @param exemptions [Array<Spree::TaxExemption>] the same evidence the sale
    #   was filed with, so the credit is classified the way the sale was
    # @param tax_identifier [Spree::TaxIdentifier, nil] the registration the sale
    #   was filed under, for the same reason
    def initialize(order:, integration:, return_items:, amount: nil, tax_date: nil, exemptions: [],
                   tax_identifier: nil)
      @order = order
      @integration = integration
      @return_items = Array(return_items)
      @amount = amount
      @tax_date = tax_date
      @exemptions = exemptions
      @tax_identifier = tax_identifier
    end

    # What the returned lines are worth before tax. Nothing to credit means
    # nothing to file — a return of zero-quantity lines is not a document.
    #
    # @return [BigDecimal]
    def lines_worth
      @lines_worth ||= return_items.sum { |item| credited_basis(item) }
    end

    def nothing_to_credit?
      lines_worth <= 0
    end

    # An admin may keep a restocking fee or refund a goodwill figure of their
    # own, and no more tax may be credited than the refund actually carried.
    # Where the refund falls short, every line is credited proportionally.
    #
    # The refund is measured against what the customer paid, not against the
    # net basis being credited: `amount` is money the customer receives, so on
    # a market that sells gross it carries the tax with it. Comparing it to the
    # net basis read a 90 refund of a 100 gross line as covering all of the
    # 81.30 net and credited the full tax — every shortfall smaller than the
    # tax over-credited.
    #
    # @return [BigDecimal]
    def scale
      return 1.to_d if amount.nil? || nothing_to_credit? || refunded_worth <= 0

      [amount.to_d / refunded_worth, 1.to_d].min
    end

    # @return [Hash]
    def call
      payload = {
        type: 'ReturnInvoice',
        companyCode: integration.preferred_company_code,
        code: code,
        commit: integration.preferred_commit_transaction_enabled,
        date: document_date,
        currencyCode: order.currency,
        customerCode: customer_code,
        addresses: addresses,
        # The credit is taxed as of the original supply, not today: rates move,
        # and a return is a reversal of that sale rather than a new one.
        taxOverride: { type: 'TaxDate', reason: 'Refund', taxDate: supply_date },
        lines: lines
      }

      # The registration is what made the sale an intra-community supply rather
      # than a standard-rated one. A credit that drops it is re-priced as a
      # consumer refund, which declares VAT the sale never collected — the same
      # reasoning that keeps the tax code and exemption on every credit line.
      payload[:businessIdentificationNo] = tax_identifier.value if tax_identifier&.value.present?

      payload
    end

    # Keyed to the return, so a replayed Returns::Refund adjusts this document
    # rather than filing a second credit.
    #
    # @return [String]
    def code
      "#{order.number}-#{return_items.first&.return&.number}"
    end

    private

    attr_reader :order, :integration, :return_items, :amount, :tax_date, :exemptions, :tax_identifier

    # Each credit line is the sale's line rebuilt — same tax code, same origin,
    # same exemption — with the returned quantity at a negative amount. A credit
    # that drops the classification is re-priced by Avalara as generic goods for
    # a non-exempt buyer, which reclaims tax that was never collected.
    def lines
      return_items.zip(credited_amounts).filter_map do |item, credited|
        next if credited <= 0

        as_sold(item.line_item).merge(
          quantity: item.received_quantity,
          amount: -credited,
          # The amount is net by construction — it comes from pre_tax_amount —
          # so Avalara must add tax to it rather than back tax out of it. Saying
          # otherwise credits roughly 1/(1+rate) of the VAT on an inclusive
          # market and leaves the rest permanently over-declared.
          taxIncluded: false
        )
      end
    end

    def as_sold(line_item)
      ItemPresenter.new(item: line_item, owner: order, tax_included: false, exemptions: exemptions).call
    end

    # Rounding each line on its own can credit more than the refund carried:
    # two $1.00 lines scaled to a $1.03 refund each round to $0.52, crediting a
    # cent that was never refunded. Rounding the running total instead and
    # taking each line as the difference keeps the sum exactly on the cap, and
    # gives the odd cent to one line rather than to every line.
    #
    # @return [Array<BigDecimal>] one credit per return item, in order
    def credited_amounts
      cap = credit_cap
      running_basis = 0.to_d
      credited = 0.to_d

      return_items.map do |item|
        running_basis += credited_basis(item)
        target = [(running_basis * scale).round(2), cap].min
        line = target - credited
        credited = target
        line
      end
    end

    # The net share of the refund, which is what the credit lines add up to.
    # Deliberately not also capped at `amount`: that figure is gross on a market
    # that sells gross, so taking it as a ceiling on a net total would be
    # comparing two different things — `scale` has already measured the refund
    # against a like basis.
    def credit_cap
      (lines_worth * scale).round(2)
    end

    # What the customer is being refunded against: the returned units at their
    # sale value, tax included where the sale included it. This is the same
    # figure core computes for `ReturnLineItem#pre_tax_amount` — from
    # `line_item.amount` despite the name — so the refund `amount` and this are
    # in the same terms by construction. Where a sale carries no included tax
    # it equals `lines_worth` and scaling is unchanged.
    def refunded_worth
      @refunded_worth ||= return_items.sum { |item| refunded_basis(item) }
    end

    def refunded_basis(return_item)
      line_item = return_item.line_item
      return 0.to_d if line_item.nil? || line_item.quantity.to_i.zero?

      (line_item.amount.to_d / line_item.quantity) * return_item.received_quantity.to_i
    end

    # Per unit rather than per line: a partial return credits what came back.
    def credited_basis(return_item)
      line_item = return_item.line_item
      return 0.to_d if line_item.nil? || line_item.quantity.to_i.zero?

      (line_item.pre_tax_amount.to_d / line_item.quantity) * return_item.received_quantity.to_i
    end

    def supply_date
      zone = Time.find_zone(order.store&.preferred_timezone) || Time.zone

      (tax_date || order.completed_at || Time.current).in_time_zone(zone).to_date.iso8601
    end

    alias document_date supply_date

    def customer_code
      order.customer&.prefixed_id.presence || order.email.presence || order.prefixed_id
    end

    def addresses
      {
        shipFrom: AddressPresenter.new(SpreeAvalara.origin_location(order)).call,
        shipTo: AddressPresenter.new(order.tax_address).call
      }.compact
    end
  end
end
