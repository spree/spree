module SpreeAvalara
  # The fingerprint of an estimate request. Avalara prices a whole document per
  # call while Spree re-estimates per item change, so several call sites in one
  # request would otherwise each pay a round trip inside the cart's own
  # transaction.
  #
  # Everything that can change the answer belongs in the key. Notably the
  # *resolved* inclusiveness rather than the cart's market flag: an address
  # change that flips it has to bust the key instead of serving a stale
  # calculation.
  class EstimateCacheKey
    EXPIRES_IN = 5.minutes

    # @param owner [Spree::Cart, Spree::Order]
    # @param items [Array<Spree::LineItem, Spree::Fulfillment, Spree::Fee>]
    # @param integration [SpreeAvalara::Integration]
    # @param tax_identifier [Spree::TaxIdentifier, nil]
    # @param exemptions [Array<Spree::TaxExemption>]
    def initialize(owner:, items:, integration:, tax_identifier: nil, exemptions: [])
      @owner = owner
      @items = items
      @integration = integration
      @tax_identifier = tax_identifier
      @exemptions = exemptions
    end

    # @return [String]
    def key
      [
        'spree_avalara/estimate',
        owner.class.name.demodulize.downcase,
        owner.id,
        Digest::SHA256.hexdigest(fingerprint.to_json)
      ].join('/')
    end

    private

    attr_reader :owner, :items, :integration, :tax_identifier, :exemptions

    def fingerprint
      {
        integration: [integration.id, integration.updated_at.to_i, integration.preferred_company_code],
        tax_address: tax_address,
        market: owner.market&.id,
        tax_included: SpreeAvalara.tax_inclusive?(owner),
        currency: owner.currency,
        identifier: tax_identifier && [tax_identifier.kind, tax_identifier.value],
        exemptions: exemptions.map { |exemption| exemption_fingerprint(exemption) },
        items: items.map { |item| item_fingerprint(item) }
      }
    end

    def tax_address
      address = owner.tax_address
      return if address.nil?

      [address.address1, address.address2, address.city, address.state_code,
       address.country_code, address.zipcode]
    end

    def exemption_fingerprint(exemption)
      [exemption.reason_code, exemption.certificate_number, exemption.country_code, exemption.state_code]
    end

    # Ship-from belongs here because the origin jurisdiction moves the answer,
    # and a re-allocated fulfillment changes it without touching the item.
    def item_fingerprint(item)
      [
        item.prefixed_id,
        item.respond_to?(:quantity) ? item.quantity : 1,
        (item.respond_to?(:taxable_basis) ? item.taxable_basis : item.amount).to_s,
        item.respond_to?(:tax_category_id) ? item.tax_category_id : nil,
        ship_from_id(item)
      ]
    end

    def ship_from_id(item)
      SpreeAvalara.origin_location(owner, item: item)&.id
    end
  end
end
