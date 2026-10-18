module SpreeAvalara
  # The tax a return, claim or exchange gave back, as AvaTax's ReturnInvoice:
  # each credited line at a negative amount, keyed to the record so filing it
  # twice adjusts one document.
  #
  # The tax on each line is not Avalara's to work out again. Core has already
  # written it as the line's credit rows, from what the sale charged, and
  # refunded the customer exactly that (see Spree::TaxProvider::Base#refund).
  # So every line carries it as a tax-amount override: re-quoting the credit
  # against the list price, or against rates that have moved since, filed a
  # figure the customer was never repaid.
  #
  # Deliberately line-level rather than the percentage RefundTransactionModel —
  # the contract credits the lines that came back, not a share of the order.
  class RefundPresenter
    # @param order [Spree::Order]
    # @param integration [SpreeAvalara::Integration]
    # @param return_items [Array<Spree::ReturnLineItem, Spree::ClaimLineItem, Spree::ExchangeLineItem>]
    # @param amount [BigDecimal, nil] what the customer was actually refunded,
    #   tax included; nil means the lines' full worth
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

    # A refund of nothing is not a document.
    def nothing_to_credit?
      refunded.values.sum <= 0
    end

    # @return [Hash]
    def call
      payload = {
        type: 'ReturnInvoice',
        companyCode: integration.preferred_company_code,
        code: code,
        commit: integration.preferred_commit_transaction_enabled,
        # Filed on the day the money went back, so the credit lands in the
        # period it happened in rather than reopening the sale's.
        date: date_in_store_zone(Time.current),
        currencyCode: order.currency,
        customerCode: customer_code,
        addresses: addresses,
        # Classified as of the original supply, not today: a return reverses
        # that sale rather than making a new one.
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

    # Keyed to the return, claim or exchange rather than to the order, so a
    # replayed refund adjusts this document and a second return of the same
    # order files a document of its own.
    #
    # @return [String]
    def code
      "#{order.number}-#{SpreeAvalara.post_sale_record(return_items.first)&.number}"
    end

    private

    attr_reader :order, :integration, :return_items, :amount, :tax_date, :exemptions, :tax_identifier

    # Each credit line is the sale's line rebuilt — same tax code, same origin,
    # same exemption — with the credited units, the money that went back for
    # them before tax, and the tax that went back with it.
    def lines
      return_items.filter_map do |item|
        money = refunded.fetch(item)
        next if money <= 0

        tax = item.credited_tax_total.to_d
        as_sold(item.line_item).merge(
          quantity: item.credited_quantity,
          amount: -[money - tax, 0.to_d].max,
          # Net by construction, as the override below is the whole tax.
          taxIncluded: false,
          taxOverride: { type: 'TaxAmount', reason: 'Refund', taxAmount: -tax, taxDate: supply_date }
        )
      end
    end

    def as_sold(line_item)
      ItemPresenter.new(item: line_item, owner: order, tax_included: false, exemptions: exemptions).call
    end

    # The money each line got back, tax included. A short refund — a
    # restocking fee, a part refund — is divided in proportion to what each
    # line is worth, to the cent, which is how core divided it before writing
    # the credit rows.
    #
    # @return [Hash{Object => BigDecimal}]
    def refunded
      @refunded ||= begin
        worth = return_items.index_with { |item| item.credited_worth.to_d }
        total = worth.values.sum

        if amount.nil? || amount.to_d >= total
          worth
        else
          divide(amount.to_d, worth)
        end
      end
    end

    def divide(money, worth)
      weights = worth.values.map { |value| to_minor_units(value) }
      return worth.transform_values { 0.to_d } if weights.sum.zero?

      shares = Spree::Adjusters::LargestRemainder.largest_remainder_shares(to_minor_units(money), weights)
      worth.keys.zip(shares).to_h do |item, cents|
        [item, Spree::Money::Rounding.from_minor_units(cents, order.currency)]
      end
    end

    def to_minor_units(value)
      Spree::Money::Rounding.to_minor_units(value, order.currency)
    end

    def supply_date
      date_in_store_zone(tax_date || order.completed_at || Time.current)
    end

    def date_in_store_zone(time)
      zone = Time.find_zone(order.store&.preferred_timezone) || Time.zone

      time.in_time_zone(zone).to_date.iso8601
    end

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
