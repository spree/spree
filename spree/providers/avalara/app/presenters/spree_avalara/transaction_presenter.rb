module SpreeAvalara
  # A whole cart or order as AvaTax's CreateTransactionModel, shared by the
  # estimate and the filing so the two can never describe the same sale
  # differently.
  class TransactionPresenter
    # @param owner [Spree::Cart, Spree::Order]
    # @param integration [SpreeAvalara::Integration]
    # @param items [Array<Spree::LineItem, Spree::Fulfillment, Spree::Fee>]
    # @param type [String] 'SalesOrder' to quote, 'SalesInvoice' to file
    # @param code [String, nil] document code; Avalara generates one for a quote
    # @param commit [Boolean] file the document as committed
    # @param tax_date [Time, nil] the date whose rates apply
    # @param tax_identifier [Spree::TaxIdentifier, nil] the buyer's registration
    # @param exemptions [Array<Spree::TaxExemption>] accepted; placement is Phase 4
    def initialize(owner:, integration:, items:, type:, code: nil, commit: false,
                   tax_date: nil, tax_identifier: nil, exemptions: [])
      @owner = owner
      @integration = integration
      @items = items
      @type = type
      @code = code
      @commit = commit
      @tax_date = tax_date
      @tax_identifier = tax_identifier
      @exemptions = exemptions
    end

    # @return [Hash]
    def call
      payload = {
        type: type,
        companyCode: integration.preferred_company_code,
        date: document_date,
        commit: commit,
        currencyCode: owner.currency,
        customerCode: customer_code,
        addresses: addresses,
        lines: lines
      }

      payload[:code] = code if code.present?
      payload[:businessIdentificationNo] = tax_identifier.value if tax_identifier&.value.present?
      payload
    end

    private

    attr_reader :owner, :integration, :items, :type, :code, :commit,
                :tax_date, :tax_identifier, :exemptions

    # Which day's rates apply, read in the store's own zone: a merchant closing
    # a sale late on the 31st means their 31st, not the server's next morning.
    def document_date
      zone = Time.find_zone(owner.store&.preferred_timezone) || Time.zone

      (tax_date || Time.current).in_time_zone(zone).to_date.iso8601
    end

    # Avalara keys exemption certificates and reporting to this, so it has to be
    # stable for the buyer rather than per order.
    def customer_code
      owner.customer&.prefixed_id.presence || owner.email.presence || owner.prefixed_id
    end

    def addresses
      {
        shipFrom: AddressPresenter.new(owner.fulfillments.first&.stock_location).call,
        shipTo: AddressPresenter.new(owner.tax_address).call
      }.compact
    end

    def lines
      tax_included = SpreeAvalara.tax_inclusive?(owner)

      items.map do |item|
        ItemPresenter.new(item: item, owner: owner, tax_included: tax_included).call
      end
    end
  end
end
