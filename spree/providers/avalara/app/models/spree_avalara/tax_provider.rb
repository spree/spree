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

    # Fails closed on a service failure — an Avalara that refuses or cannot be
    # reached raises, because silently under-collecting is a liability the
    # merchant discovers in a filing.
    #
    # Being *disconnected* is different, and deliberately not a failure. An
    # integration is an operational toggle: a merchant connects providers at
    # different stages, deactivates one to change credentials, activates it
    # again. None of that may decide whether a customer can add to their cart or
    # place an order, so an unconnected provider simply has no opinion and writes
    # no rows.
    #
    # @see Spree::TaxProvider::Base#estimate
    def estimate(owner, items = nil, tax_date: nil, tax_identifier: nil, exemptions: [], context: {})
      integration = Integration.active_for(owner.store)
      taxable = owner.taxable_items

      # Nothing to price: no items, nowhere to ship, or nothing connected to ask.
      # The stale rows go and nothing replaces them — each item is worth its whole
      # basis again, which is what Internal does when no rate matches.
      if integration.nil? || taxable.empty? || owner.tax_address.nil?
        report_disconnected(owner) if integration.nil?
        sweep!(owner)
        taxable.each { |item| reset_pre_tax_amount(item) }
        return
      end

      body = fetch(owner, taxable, integration, tax_date, tax_identifier, exemptions)
      lines = TransactionLine.from_response(body, context: response_context(owner, tax_identifier, exemptions))

      ApplicationRecord.transaction do
        sweep!(owner)
        write_lines(owner, taxable, lines)
      end
    rescue SpreeAvalara::RequestError => error
      raise tax_failure(error)
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
      integration = Integration.active_for(order.store)
      # Nothing connected to file with. Reported rather than raised: refusing to
      # complete an order the customer has already paid for is worse than a sale
      # the merchant has to file by hand.
      return report_disconnected(order) if integration.nil?

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
      raise tax_failure(error) unless integration.client.duplicate_document_error?(error)
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
      raise tax_failure(error) unless integration.client.already_voided_error?(error)
    end

    # Credits the returned lines against the filed document.
    #
    # @param order [Spree::Order]
    # @param return_items [Array<Spree::ReturnLineItem>]
    # @param amount [BigDecimal, nil] the refund issued; nil = the lines' worth
    # @param tax_date [Time, nil] the original supply date
    # @return [void]
    def refund(order, return_items, amount: nil, tax_date: nil)
      integration = Integration.active_for(order.store)
      # Nothing was filed through an integration that is not connected, so there
      # is nothing to credit — the same reasoning as void.
      return report_disconnected(order) if integration.nil?

      presenter = RefundPresenter.new(
        order: order, integration: integration, return_items: return_items,
        amount: amount, tax_date: tax_date, exemptions: order.usable_exemptions
      )
      return if presenter.nothing_to_credit?

      integration.client.create_transaction(presenter.call)
    rescue SpreeAvalara::RequestError => error
      raise tax_failure(error) unless integration.client.duplicate_document_error?(error)
    end

    private

    # Which of core's two failures an AvaTax error is, decided by whether
    # Avalara answered at all.
    #
    # No status means nothing was answered — the network, a timeout, retries
    # exhausted — and a later attempt may well succeed. A 5xx is the same
    # shape: Avalara's own fault, not the request's.
    #
    # Anything else is Avalara saying no to this particular request: an address
    # it will not accept, a company code that does not exist. The service is
    # working and retrying is pointless, so the caller must be able to tell the
    # customer what was wrong instead of asking them to try again. Avalara's own
    # message is carried across, because it names the problem better than
    # anything this gem could invent.
    def tax_failure(error)
      status = error.status.to_i
      unavailable = error.status.nil? || status >= 500

      failure = unavailable ? Spree::Tax::ProviderUnavailable : Spree::Tax::CalculationRefused
      failure.new(error.message, provider_key: SpreeAvalara::PROVIDER_ID)
    end

    # A market calculating through Avalara with nothing connected produces no tax
    # at all, which is visible in the storefront and the dashboard — but the
    # reason is not, so it is reported where the host collects errors.
    def report_disconnected(owner)
      Rails.error.report(
        SpreeAvalara::NotConfiguredError.new(
          "Store #{owner.store_id.inspect} calculates tax through Avalara, but no integration is connected"
        ),
        handled: true,
        context: { store_id: owner.store_id, owner: owner.class.name, owner_id: owner.id },
        source: 'spree_avalara'
      )

      nil
    end

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

    def reset_pre_tax_amount(item)
      return unless item.respond_to?(:pre_tax_amount)

      item.update_column(:pre_tax_amount, basis_for(item))
    end

    def basis_for(item)
      item.respond_to?(:taxable_basis) ? item.taxable_basis : item.amount
    end

    # Mirrors Internal#store_pre_tax_amount: what the item is worth before tax,
    # which the refund path reads back. Only included-in-price tax comes out of
    # the basis; additional tax sits on top of it.
    def store_pre_tax_amount(item, lines)
      return unless item.respond_to?(:pre_tax_amount)

      basis = basis_for(item)
      line = lines.find { |candidate| candidate.line_number.to_s == item.prefixed_id.to_s }
      basis -= line.amount if line&.included?

      item.update_column(:pre_tax_amount, basis)
    end

    # What the response cannot say for itself: whether a registration was sent,
    # whether an exemption was claimed, and the two ends of the supply.
    def response_context(owner, tax_identifier, exemptions)
      {
        identifier_sent: tax_identifier&.value.present?,
        exemption_reasons: Array(exemptions).map(&:reason_code).compact,
        ship_from_country: SpreeAvalara.origin_location(owner)&.country_code,
        ship_to_country: owner.tax_address&.country_code
      }
    end
  end
end
