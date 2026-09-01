module SpreeAvalara
  # One taxable item as AvaTax's LineItemModel.
  class ItemPresenter
    # Avalara's generic tangible-goods code, and its freight code. Used when the
    # merchant has classified neither the item nor a default category, which is
    # parity with the Internal engine taxing category-less items by default.
    DEFAULT_TAX_CODE = 'P0000000'.freeze
    FREIGHT_TAX_CODE = 'FR'.freeze

    # @param item [Spree::LineItem, Spree::Fulfillment, Spree::Fee]
    # @param owner [Spree::Cart, Spree::Order]
    # @param tax_included [Boolean] resolved through the tax destination
    # @param exemptions [Array<Spree::TaxExemption>] entries to place on this
    #   line; empty when the claim was placed on the document instead
    def initialize(item:, owner:, tax_included:, exemptions: [])
      @item = item
      @owner = owner
      @tax_included = tax_included
      @exemptions = exemptions
    end

    # @return [Hash]
    def call
      payload = {
        number: item.prefixed_id,
        quantity: quantity,
        amount: amount,
        taxIncluded: tax_included,
        # 6.0 distributes order-level promotions into the taxable basis, so the
        # line arrives already discounted. Telling Avalara to discount it again
        # would take the reduction twice.
        discounted: false,
        discount: 0
      }

      payload[:taxCode] = tax_code if tax_code.present?
      payload[:addresses] = { shipFrom: ship_from } if ship_from.present?
      payload.merge!(exemption_payload)
      payload
    end

    private

    attr_reader :item, :owner, :tax_included, :exemptions

    # The first entry claiming both this line and the jurisdiction being taxed.
    # Multiple certificates mean multiple entries, and one claim is enough —
    # the same rule Internal applies.
    def exemption_payload
      entry = exemptions.find do |exemption|
        exemption.covers_item?(item) &&
          exemption.covers_jurisdiction?(destination_country, destination_state)
      end
      return {} if entry.nil?

      code = EntityUseCodes.for(entry.reason_code_for(item))
      payload = code ? { entityUseCode: code } : {}
      payload[:exemptionCode] = entry.certificate_number if entry.certificate_number.present?
      payload
    end

    def destination_country
      owner.tax_address&.country_code
    end

    def destination_state
      owner.tax_address&.state_code
    end

    def quantity
      item.respond_to?(:quantity) ? item.quantity : 1
    end

    def amount
      item.respond_to?(:taxable_basis) ? item.taxable_basis : item.amount
    end

    def tax_code
      case item
      when Spree::LineItem then item.tax_category&.tax_code.presence || default_tax_code || DEFAULT_TAX_CODE
      when Spree::Fulfillment then delivery_tax_code.presence || FREIGHT_TAX_CODE
      else default_tax_code
      end
    end

    # A fulfillment carries no tax category of its own — the delivery method it
    # was rated with does.
    def delivery_tax_code
      item.selected_delivery_rate&.delivery_method&.tax_category&.tax_code
    end

    def default_tax_code
      Spree::TaxCategory.default(owner.store)&.tax_code
    end

    # Where this line ships from, which decides the origin jurisdiction. A line
    # item is reached through its fulfillments; anything without one falls back
    # to the owner's first, so a fee is taxed from the same origin as the goods.
    def ship_from
      AddressPresenter.new(SpreeAvalara.origin_location(owner, item: item)).call
    end
  end
end
