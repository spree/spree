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

    # Files the sale with Avalara once it is placed.
    #
    # Idempotent, because completion is replayable: a crash between the order
    # commit and the cart stamp leaves Carts::Complete to re-run its finalize
    # phase. create_or_adjust_transaction keyed on the order number adjusts the
    # document rather than filing a second one, and a duplicate refusal counts
    # as the success it describes.
    #
    # @param order [Spree::Order]
    # @return [void]
    def commit(order)
      integration = Integration.active_for!(order.store)

      body = integration.client.create_or_adjust_transaction(
        createTransactionModel: TransactionPresenter.new(
          owner: order, integration: integration, items: order.taxable_items,
          type: 'SalesInvoice', code: order.number,
          commit: integration.preferred_commit_transaction_enabled,
          tax_date: order.completed_at,
          # The order's frozen snapshot, not a fresh resolution: what was
          # filed has to match what was charged.
          tax_identifier: order.resolved_tax_identifier,
          exemptions: order.usable_exemptions
        ).call
      )

      stamp_document_id(order, body['id'])
    rescue SpreeAvalara::RequestError => error
      raise unless integration.client.duplicate_document_error?(error)
    end

    # Reverses the filed document when the order is cancelled.
    #
    # @param order [Spree::Order]
    # @return [void]
    def void(order)
      integration = Integration.active_for(order.store)
      # Nothing was ever filed through an integration that is not connected, so
      # there is nothing to reverse. Unlike estimate, this does not fail closed:
      # refusing to cancel an order because a tax service is unreachable helps
      # nobody.
      return if integration.nil?

      integration.client.void_transaction(order.number)
    rescue SpreeAvalara::RequestError => error
      raise unless integration.client.already_voided_error?(error)
    end

    # Credits the returned lines against the filed document.
    #
    # @param order [Spree::Order]
    # @param return_items [Array<Spree::ReturnLineItem>]
    # @param amount [BigDecimal, nil] the refund issued; nil = the lines' worth
    # @param tax_date [Time, nil] the original supply date
    # @return [void]
    def refund(order, return_items, amount: nil, tax_date: nil)
      integration = Integration.active_for!(order.store)
      presenter = RefundPresenter.new(
        order: order, integration: integration, return_items: return_items,
        amount: amount, tax_date: tax_date
      )
      return if presenter.nothing_to_credit?

      integration.client.create_transaction(presenter.call)
    rescue SpreeAvalara::RequestError => error
      raise unless integration.client.duplicate_document_error?(error)
    end

    private

    # Informational: void and refund key on the document code, which is the
    # order number. update_column because completion may replay and there is
    # nothing here to validate.
    def stamp_document_id(order, document_id)
      return if document_id.blank?

      order.metadata = (order.metadata || {}).merge('avalara_transaction_id' => document_id.to_s)
      order.update_column(:metadata, order.metadata)
    end

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
        exemption_reasons: Array(exemptions).map(&:reason_code).compact,
        ship_from_country: SpreeAvalara.origin_location(owner)&.country_code,
        ship_to_country: owner.tax_address&.country_code
      }
    end
  end
end
