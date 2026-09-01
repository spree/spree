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
    def initialize(order:, integration:, return_items:, amount: nil, tax_date: nil)
      @order = order
      @integration = integration
      @return_items = Array(return_items)
      @amount = amount
      @tax_date = tax_date
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
    # @return [BigDecimal]
    def scale
      return 1.to_d if amount.nil? || nothing_to_credit?

      [amount.to_d / lines_worth, 1.to_d].min
    end

    # @return [Hash]
    def call
      {
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
    end

    # Keyed to the return, so a replayed Returns::Refund adjusts this document
    # rather than filing a second credit.
    #
    # @return [String]
    def code
      "#{order.number}-#{return_items.first&.return&.number}"
    end

    private

    attr_reader :order, :integration, :return_items, :amount, :tax_date

    def lines
      return_items.filter_map do |item|
        credited = (credited_basis(item) * scale).round(2)
        next if credited <= 0

        {
          number: item.line_item.prefixed_id,
          quantity: item.received_quantity,
          amount: -credited,
          taxIncluded: SpreeAvalara.tax_inclusive?(order),
          discounted: false,
          discount: 0
        }
      end
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
