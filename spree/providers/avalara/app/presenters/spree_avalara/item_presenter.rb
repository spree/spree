module SpreeAvalara
  # One taxable item as AvaTax's LineItemModel.
  class ItemPresenter
    # Avalara's generic tangible-goods code, and its freight code. Used when the
    # merchant has classified neither the item nor a default category, which is
    # parity with the Internal engine taxing category-less items by default.
    DEFAULT_TAX_CODE = 'P0000000'.freeze
    FREIGHT_TAX_CODE = 'FR'.freeze

    # Avalara's own field limits. A line longer than these is refused outright,
    # so both are cut rather than sent whole.
    DESCRIPTION_LIMIT = 256
    ITEM_CODE_LIMIT = 50

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

      payload[:description] = description if description.present?
      payload[:itemCode] = item_code if item_code.present?
      payload[:taxCode] = tax_code if tax_code.present?
      payload[:addresses] = line_addresses if line_addresses
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
      # `exemptionCode` on a line, `exemptionNo` on the document. Strictly one
      # each — all four combinations checked against the sandbox, and each name
      # is ignored at the level it does not belong to:
      #
      #   document exemptionNo   -> certificate recorded
      #   document exemptionCode -> ignored
      #   line     exemptionCode -> certificate recorded
      #   line     exemptionNo   -> ignored
      #
      # Ignored means silently: the sale is still exempt, because entityUseCode
      # does that work on its own, so a wrong name here loses the certificate
      # reference from the filing without anything failing.
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

    # What a merchant reads when they open the transaction in Avalara. Without
    # it every line is an opaque prefixed id, so a filed document cannot be
    # checked against the sale it came from — which is the whole reason for
    # looking at one. Avalara echoes both fields back and neither changes what
    # is taxed: the line's own taxCode still governs, confirmed against the
    # sandbox by pricing the same line with and without an item code, including
    # one coded non-taxable.
    def description
      text = case item
             when Spree::LineItem then item.name
             when Spree::Fulfillment then delivery_description
             when Spree::Fee then item.label.presence || item.kind
             end

      text.to_s.truncate(DESCRIPTION_LIMIT).presence
    end

    def delivery_description
      name = item.selected_delivery_rate&.name.presence ||
             item.selected_delivery_rate&.delivery_method&.name.presence
      name ? "Delivery: #{name}" : 'Delivery'
    end

    # Only where the merchant has a real identifier for the thing sold. Avalara
    # reads an item code against the company's own item catalogue, so inventing
    # one for a fulfillment or a fee would put a value into that namespace that
    # the merchant never assigned.
    def item_code
      return unless item.is_a?(Spree::LineItem)

      item.variant&.sku.presence&.first(ITEM_CODE_LIMIT)
    end

    # A fulfillment carries no tax category of its own — the delivery method it
    # was rated with does.
    def delivery_tax_code
      item.selected_delivery_rate&.delivery_method&.tax_category&.tax_code
    end

    def default_tax_code
      Spree::TaxCategory.default(owner.store)&.tax_code
    end

    # Both ends of the supply, or neither.
    #
    # A line-level block naming only a shipFrom makes AvaTax source the line
    # *to* that origin: a California warehouse shipping to Montana came back
    # taxed at 7.25% California sales tax instead of Montana's nothing, so every
    # customer was charged the warehouse's state rather than their own. Verified
    # against the sandbox — shipFrom alone re-sources, shipFrom with shipTo does
    # not.
    #
    # The origin is per line, because an order can ship from several warehouses;
    # the destination is the owner's, and identical on every line.
    def line_addresses
      origin = AddressPresenter.new(SpreeAvalara.origin_location(owner, item: item)).call
      destination = AddressPresenter.new(owner.tax_address).call
      return if origin.blank? || destination.blank?

      { shipFrom: origin, shipTo: destination }
    end
  end
end
