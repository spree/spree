module SpreeAvalara
  # Computes tax through Avalara AvaTax. The only sanctioned writer of this
  # gem's Spree::TaxLine rows.
  #
  # Avalara prices a whole document per call, so +estimate+ ignores the +items+
  # subset it is handed and always sends the whole owner, rewriting every row it
  # owns. That is legitimate under the contract — a provider may rewrite beyond
  # the subset provided it rewrites everything it deletes — and the response
  # cache is what keeps the single-item call sites affordable.
  class TaxProvider < Spree::TaxProvider::Base
    # AvaTax handles US local tax, reverse charge and proportional delivery tax
    # natively. EU one-stop-shop thresholds depend on the merchant's own Avalara
    # company profile rather than on this gem, so there is nothing here to warn
    # a merchant about.
    def self.unsupported_capabilities
      []
    end

    def self.display_name
      'Avalara AvaTax'
    end

    # Fails closed. A market naming this provider with no connected integration,
    # or an Avalara that cannot be reached, raises rather than writing no rows:
    # silently under-collecting is a liability the merchant discovers in a
    # return, while a raise surfaces at checkout where it can be fixed.
    #
    # @see Spree::TaxProvider::Base#estimate
    def estimate(owner, items = nil, tax_date: nil, tax_identifier: nil, exemptions: [], context: {})
      integration = Integration.active_for!(owner.store)
      taxable = owner.taxable_items

      # No items or nowhere to ship means Avalara has nothing to price. That is
      # an absence of opinion rather than a failure, so the stale rows go and
      # nothing replaces them.
      return sweep!(owner) if taxable.empty? || owner.tax_address.nil?

      body = fetch(owner, taxable, integration, tax_date, tax_identifier, exemptions)
      lines = TransactionLine.from_response(body, context: response_context(owner, tax_identifier, exemptions))

      ApplicationRecord.transaction do
        sweep!(owner)
        write_lines(owner, taxable, lines)
      end
    end

    private

    # Provider-scoped: another engine's rows on the same owner — the import VAT
    # a landed-cost provider writes against a duty — are not ours to delete.
    def sweep!(owner)
      owner.tax_lines.where(provider_id: SpreeAvalara::PROVIDER_ID).delete_all

      nil
    end

    def fetch(owner, taxable, integration, tax_date, tax_identifier, exemptions)
      cache_key = EstimateCacheKey.new(
        owner: owner, items: taxable, integration: integration,
        tax_identifier: tax_identifier, exemptions: exemptions
      )

      # Only successes are cached: the block raises on a refusal, which
      # Rails.cache does not store.
      Rails.cache.fetch(cache_key.key, expires_in: EstimateCacheKey::EXPIRES_IN) do
        integration.client.create_transaction(
          TransactionPresenter.new(
            owner: owner, integration: integration, items: taxable, type: 'SalesOrder',
            tax_date: tax_date, tax_identifier: tax_identifier, exemptions: exemptions
          ).call
        )
      end
    end

    def write_lines(owner, taxable, lines)
      lines.each do |line|
        item = line.matching_item(taxable)
        Spree::TaxLine.create!(line.to_tax_line_attributes(item: item, owner: owner))
      end

      taxable.each { |item| store_pre_tax_amount(item, lines) }
    end

    # Mirrors Internal#store_pre_tax_amount: what the item is worth before tax,
    # which the refund path reads back. Only included-in-price tax comes out of
    # the basis; additional tax sits on top of it.
    def store_pre_tax_amount(item, lines)
      return unless item.respond_to?(:pre_tax_amount)

      basis = item.respond_to?(:taxable_basis) ? item.taxable_basis : item.amount
      line = lines.find { |candidate| candidate.line_number.to_s == item.prefixed_id.to_s }
      basis -= line.amount if line&.included?

      item.update_column(:pre_tax_amount, basis)
    end

    # What the response cannot say for itself: whether a registration was sent,
    # whether an exemption was claimed, and the two ends of the supply.
    def response_context(owner, tax_identifier, exemptions)
      {
        identifier_sent: tax_identifier&.value.present?,
        exemption_sent: exemptions.present?,
        ship_from_country: owner.fulfillments.first&.stock_location&.country_code,
        ship_to_country: owner.tax_address&.country_code
      }
    end
  end
end
