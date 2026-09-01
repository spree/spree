module SpreeAvalara
  # One line of an AvaTax transaction response, translated into the vocabulary
  # {Spree::TaxLine} stores. Named `TransactionLine` rather than `TaxLine` so a
  # bare `TaxLine` inside this gem still resolves to core's model.
  #
  # Avalara answers per line, and Spree writes one row per line, so the
  # jurisdiction breakdown collapses into a summed rate and a label — the whole
  # breakdown rides along in `data` for anyone who needs to re-derive it.
  class TransactionLine
    include ActiveModel::Model
    include ActiveModel::Attributes

    # Avalara says "absent" with an empty string or a zero, never a null, so
    # every predicate below tests presence rather than nil-ness.
    attribute :payload, default: -> { {} }

    # What the request said, for the treatments Avalara reports but does not
    # explain: whether a buyer registration was sent, whether an exemption was
    # claimed, and the two countries the supply moved between.
    attribute :context, default: -> { {} }

    class << self
      # @param body [Hash] a create/adjust transaction response
      # @param context [Hash] request-side facts (see the +context+ attribute)
      # @return [Array<SpreeAvalara::TransactionLine>]
      def from_response(body, context: {})
        Array(body['lines']).map { |line| new(payload: line, context: context) }
      end
    end

    # @return [String, nil] the prefixed id this line was sent as
    def line_number
      payload['lineNumber'].presence
    end

    # The item this line priced. An unmatched lineNumber is a protocol
    # violation, not a row to drop: Avalara answered about something we did not
    # ask about, and silently ignoring it would leave an item untaxed.
    #
    # @param items [Array<Spree::LineItem, Spree::Fulfillment, Spree::Fee>]
    # @return [Spree::LineItem, Spree::Fulfillment, Spree::Fee]
    # @raise [SpreeAvalara::Error] when no item carries that prefixed id
    def matching_item(items)
      item = items.find { |candidate| candidate.prefixed_id.to_s == line_number.to_s }
      return item if item

      raise SpreeAvalara::Error, "AvaTax returned line #{line_number.inspect}, which was never sent"
    end

    # @param item [Spree::LineItem, Spree::Fulfillment, Spree::Fee]
    # @param owner [Spree::Cart, Spree::Order]
    # @return [Hash] attributes for Spree::TaxLine.create!
    def to_tax_line_attributes(item:, owner:)
      {
        owner_key(owner) => owner,
        foreign_key(item) => item.id,
        tax_rate_id: nil,
        amount: amount,
        rate: rate,
        label: label,
        included: included?,
        provider_id: SpreeAvalara::PROVIDER_ID,
        taxability_reason: taxability_reason(item),
        country_code: country_code,
        state_code: state_code,
        data: { 'avalara' => avalara_data }
      }
    end

    # @return [BigDecimal] tax Avalara computed for this line
    def amount
      payload['taxCalculated'].to_d
    end

    # The jurisdictions' rates summed, since one row stands for all of them.
    #
    # @return [BigDecimal]
    def rate
      details.sum { |detail| detail['rate'].to_d }.round(6)
    end

    def included?
      payload['taxIncluded'] == true
    end

    # The distinct tax names Avalara applied. A US line can carry state, county
    # and city taxes; naming them all beats a generic label, and the full
    # breakdown is in `data` either way.
    #
    # @return [String]
    def label
      names = details.filter_map { |detail| detail['taxName'].presence }.uniq
      return 'Tax' if names.empty?

      names.join(', ').truncate(255)
    end

    # Where the tax was levied, read off the jurisdiction that levied it and
    # falling back to where the request said the goods went.
    def country_code
      details.first&.dig('country').presence || context[:ship_to_country]
    end

    # Only a region that genuinely is a subdivision of the country. For a tax
    # levied at country level Avalara repeats the country in `region` — a German
    # sale comes back `country: "DE", region: "DE"` — which core's geography
    # validation rejects, and the whole estimate would fail with it. Resolving
    # through core's own ISO data both filters and canonicalises.
    def state_code
      region = details.first&.dig('region').presence
      return if region.nil? || country_code.blank?

      Spree::IsoData.subdivision_code(country_code, region)
    end

    # The treatment, folded from Avalara's own reason fields. First match wins,
    # and the order matters: a line with no nexus also reports
    # `isItemTaxable: false`, so the product-exemption test has to be narrower
    # than that flag.
    #
    # @param item [Spree::LineItem, Spree::Fulfillment, Spree::Fee]
    # @return [String] one of Spree::TaxLine.taxability_reasons
    def taxability_reason(item)
      return 'customer_exempt' if customer_exempt?
      return 'intra_community_supply' if intra_community_supply?(item)
      return 'reverse_charge' if reverse_charge?(item)
      return 'export' if export?
      return 'product_exempt' if product_exempt?
      return 'not_collecting' if not_collecting?
      return 'not_subject_to_tax' if not_subject_to_tax?
      return 'reduced_rated' if reduced_rated?
      return 'standard_rated' if rate.positive? || amount.positive?

      'zero_rated'
    end

    private

    def details
      Array(payload['details'])
    end

    def line_amount
      payload['lineAmount'].to_d
    end

    def exempt_amount
      payload['exemptAmount'].to_d
    end

    # A certificate has to exist for *this line* to claim one. `exemptAmount`
    # alone says nothing — a sale into a state with no nexus reports the whole
    # line exempt — and neither does an order-wide "we sent something", because
    # a claim may cover some lines and not others.
    #
    # Avalara echoes back the code it applied, so the line is its own evidence.
    # Where it echoes nothing the row falls through to a zero-tax reason, which
    # under-claims rather than naming a certificate that does not exist.
    def customer_exempt?
      return false unless exempt_amount.positive?

      payload['exemptCertId'].to_i.positive? ||
        payload['exemptNo'].to_s.present? ||
        payload['entityUseCode'].to_s.present?
    end

    # Avalara reports the zero rate but not why it is zero, so the EU split
    # comes from what the request described: a registered buyer, goods crossing
    # an internal border.
    def intra_community_supply?(item)
      zero_vat? && context[:identifier_sent] == true && goods?(item) && cross_border?
    end

    # A cross-border supply to a registered buyer that is not goods: the service
    # case the EU reverse-charges. Deliberately narrow rather than "whatever
    # intra-community supply did not claim" — a domestic zero-rated sale (books,
    # food) to a customer who happens to hold a registration is zero_rated, and
    # calling it reverse charge files it under the wrong e-invoice category.
    #
    # Domestic reverse charge (construction and the like) is indistinguishable
    # from zero-rating in the payload, so it reads zero_rated until a cassette
    # shows a marker that separates them.
    def reverse_charge?(item)
      zero_vat? && context[:identifier_sent] == true && cross_border? && !goods?(item)
    end

    def zero_vat?
      return false unless rate.zero?

      details.any? { |detail| detail['rateTypeCode'].to_s == 'Z' } || payload['vatCode'].to_s.present?
    end

    def goods?(item)
      item.is_a?(Spree::Fee) ? false : true
    end

    def cross_border?
      from = context[:ship_from_country].to_s
      to = context[:ship_to_country].to_s

      from.present? && to.present? && from != to
    end

    def export?
      details.any? { |detail| detail['nonTaxableType'].to_s == 'Export' }
    end

    # Tax applies in this jurisdiction — the rate is real — but not to this
    # line. That is a product rule, distinct from not being registered at all.
    def product_exempt?
      details.any? do |detail|
        detail['taxType'].to_s == 'Sales' &&
          detail['rate'].to_d.positive? &&
          detail['nonTaxableAmount'].to_d == line_amount &&
          line_amount.positive?
      end
    end

    # `Use` is how Avalara says the seller is not registered to collect here, so
    # whatever is owed is the buyer's use tax. The zeros are load-bearing:
    # several states call what a *registered* out-of-state seller collects
    # "seller's use tax", and that line is collected tax, not an absence of it.
    def not_collecting?
      return true if details.empty?
      return true if details.any? { |detail| detail['nonTaxableType'].to_s == 'NexusRule' }

      details.any? do |detail|
        detail['taxType'].to_s == 'Use' && detail['rate'].to_d.zero? && detail['taxCalculated'].to_d.zero?
      end
    end

    # The jurisdiction levies no such tax at all, which is a different statement
    # from "zero-rated under this regime".
    def not_subject_to_tax?
      details.present? &&
        details.all? { |detail| detail['rate'].to_d.zero? } &&
        details.any? { |detail| detail['nonTaxableType'].to_s == 'RateRule' }
    end

    def reduced_rated?
      rate.positive? && details.any? { |detail| detail['rateTypeCode'].to_s == 'R' }
    end

    def owner_key(owner)
      owner.is_a?(Spree::Order) ? :order : :cart
    end

    def foreign_key(item)
      case item
      when Spree::LineItem then :line_item_id
      when Spree::Fulfillment then :fulfillment_id
      when Spree::Fee then :fee_id
      else raise SpreeAvalara::Error, "#{item.class} is not taxable"
      end
    end

    # Everything needed to explain or re-derive the row later, without keeping
    # the whole response.
    def avalara_data
      {
        'details' => details,
        'exemptAmount' => payload['exemptAmount'],
        'exemptCertId' => payload['exemptCertId'],
        'exemptNo' => payload['exemptNo'],
        'entityUseCode' => payload['entityUseCode'],
        'isItemTaxable' => payload['isItemTaxable'],
        'taxCode' => payload['taxCode'],
        'vatCode' => payload['vatCode'],
        # An exemption reason core does not share with Avalara is sent as
        # OTHER/CUSTOM, so the reason the merchant actually recorded is kept here
        # rather than lost to the translation.
        'sent_exemption_reasons' => context[:exemption_reasons].presence
      }.compact
    end
  end
end
