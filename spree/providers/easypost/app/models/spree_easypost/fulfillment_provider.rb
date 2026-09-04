module SpreeEasyPost
  # Buys and refunds EasyPost labels for outbound parcels and returns
  # (docs/plans/6.0-shipping-labels-and-deliveries.md). Core records what
  # was bought as a Spree::ShippingLabel and never asks twice for a parcel
  # that already holds one, so nothing here remembers a purchase — the label
  # row does.
  #
  # Nothing here may raise: a purchase failure is reported and answered with
  # nil, which the explicit buy-label step surfaces as a 422 and the one-click
  # fulfill degrades to "no label yet".
  class FulfillmentProvider < Spree::FulfillmentProvider::Base
    # EasyPost carrier names → Spree.tracking_carriers keys, so a bought label
    # gets the same badge and tracking page a hand-entered number would.
    CARRIER_KEYS = {
      'USPS' => 'usps',
      'UPS' => 'ups',
      'FedEx' => 'fedex',
      'FedExDefault' => 'fedex',
      'DHLExpress' => 'dhl',
      'DhlEcs' => 'dhl',
      'DPD' => 'dpd',
      'GLS' => 'gls',
      'RoyalMail' => 'royal_mail',
      'CanadaPost' => 'canada_post',
      'AustraliaPost' => 'australia_post'
    }.freeze

    LABEL_FORMATS = {
      'application/pdf' => 'pdf',
      'image/png' => 'png',
      'application/zpl' => 'zpl',
      'text/plain' => 'zpl'
    }.freeze

    def self.integration_class
      'SpreeEasyPost::Integration'
    end

    def self.provider_name
      SpreeEasyPost::PROVIDER_NAME
    end

    def self.generates_labels?
      true
    end

    # An outbound parcel buys the rate quoted at checkout when it is still
    # valid; EasyPost quotes expire, so a stale or missing quote is re-quoted
    # from the actual fulfillment and bought only when a rate for the exact
    # carrier/service the customer selected comes back — silently shipping a
    # different service than the customer paid for is worse than no label.
    #
    # A return buys an inbound shipment from the address the order shipped
    # to back to the return's stock location, at the cheapest rate the
    # account offers: return postage is the merchant's own money and no
    # service was ever chosen for it.
    #
    # @param owner [Spree::Fulfillment, Spree::Return]
    # @return [Spree::LabelPurchase, nil]
    def purchase_label(owner)
      integration = integration_for(owner)
      return if integration.nil?

      shipment =
        if owner.is_a?(Spree::Return)
          buy_return(integration, owner)
        else
          buy_quoted(integration, owner) || requote_and_buy(integration, owner)
        end
      return if shipment.nil?

      label_purchase(shipment)
    rescue EasyPost::Errors::EasyPostError => e
      # EasyPost says exactly what is wrong — an incomplete origin address, an
      # unserviceable destination — and the merchant is the only one who can
      # fix it. Passed through rather than reported as a connection problem.
      report(e, owner)
      raise Spree::Core::LabelPurchaseRefused, e.message
    rescue StandardError => e
      report(e, owner)
      nil
    end

    # Files the refund with EasyPost. USPS refunds settle later and come
    # back as `submitted`; commercial carriers usually answer at once.
    #
    # @param shipping_label [Spree::ShippingLabel]
    # @return [String, false]
    def refund_label(shipping_label)
      # The account that sold the label, not whichever one the parcel's
      # current method points at — a rerouted parcel still owes its postage
      # back to the carrier it was bought from.
      integration = shipping_label.integration || integration_for(shipping_label.owner)
      return false if integration.nil? || shipping_label.external_id.blank?

      shipment = integration.client.shipment.refund(shipping_label.external_id)
      refund_outcome(shipment.try(:refund_status))
    rescue EasyPost::Errors::EasyPostError => e
      # A parcel already in the carrier's hands, a label too old to void:
      # EasyPost says which, and only the merchant can act on it.
      report(e, shipping_label.owner)
      raise Spree::Core::LabelRefundRefused, e.message
    rescue StandardError => e
      report(e, shipping_label.owner)
      false
    end

    # Dispatch is the label; there is nothing else to tell EasyPost.
    def create_fulfillment(_fulfillment)
      {}
    end

    def cancel_fulfillment(_fulfillment)
      true
    end

    # The tracker page EasyPost hosts for the delivery's label.
    #
    # @param delivery [Spree::Delivery]
    # @return [String, nil]
    def tracking_url(delivery)
      delivery&.shipping_label&.metadata&.dig('easypost_tracker_url')
    end

    # Customs forms and commercial invoices the purchase produced. The label
    # itself is the Spree::ShippingLabel, never listed here.
    #
    # @param owner [Spree::Fulfillment, Spree::Return]
    # @return [Array<Hash>]
    def documents(owner)
      # Read from the loaded association rather than re-scoping it: this is
      # called once per parcel while serializing an order, and a fresh query
      # each time defeats the controller's preload.
      label = owner.shipping_labels.detect { |candidate| !candidate.refunded? }
      forms = label&.metadata&.dig('easypost_forms')
      Array(forms).filter_map do |form|
        next if form['url'].blank?

        { kind: form['form_type'].presence || 'form', url: form['url'] }
      end
    end

    private

    def buy_quoted(integration, fulfillment)
      quoted = fulfillment.selected_delivery_rate&.metadata || {}
      shipment_id = quoted['easypost_shipment_id']
      rate_id = quoted['easypost_rate_id']
      return if shipment_id.blank? || rate_id.blank?

      buy(integration, fulfillment.stock_location, fulfillment.store, shipment_id, rate_id)
    rescue EasyPost::Errors::EasyPostError
      nil
    end

    def requote_and_buy(integration, fulfillment)
      # The selected rate carries the carrier service the customer chose —
      # the delivery method no longer pins one (it offers many).
      selected = fulfillment.selected_delivery_rate
      address = fulfillment.address || fulfillment.order&.ship_address

      # Each of these is the merchant's to fix, so each says so rather than
      # failing as "check the carrier connection".
      raise Spree::Core::LabelPurchaseRefused, Spree.t('easypost.errors.no_destination') if address.nil?

      if selected&.carrier.blank? || selected.service_level.blank?
        raise Spree::Core::LabelPurchaseRefused, Spree.t('easypost.errors.rate_not_quoted')
      end

      shipment = integration.client.shipment.create(
        **SpreeEasyPost.shipment_params(
          fulfillment.to_package, fulfillment.stock_location, address, integration, fulfillment.store
        )
      )
      rate = shipment.rates.find do |candidate|
        candidate.carrier == selected.carrier && candidate.service == selected.service_level
      end

      # Silently buying a different service than the customer paid for is
      # worse than no label, so this refuses and names the service.
      if rate.nil?
        raise Spree::Core::LabelPurchaseRefused,
              Spree.t('easypost.errors.service_unavailable', service: "#{selected.carrier} #{selected.service_level}")
      end

      buy(integration, fulfillment.stock_location, fulfillment.store, shipment.id, rate.id)
    end

    def buy_return(integration, return_record)
      address = return_record.ship_from_address
      return if address.nil? || return_record.stock_location.nil?

      params = SpreeEasyPost.shipment_params(
        return_record.to_package, address, return_record.stock_location, integration, return_record.store
      )
      shipment = integration.client.shipment.create(**params, is_return: true)
      rate = EasyPost::Util.get_lowest_object_rate(shipment)
      return if rate.nil?

      buy(integration, return_record.stock_location, return_record.store, shipment.id, rate.id)
    end

    # Labels bought on EasyPost's own carrier accounts (USPS) require an
    # EndShipper — the legally responsible shipping party. Created fresh per
    # purchase so it always matches the current warehouse address; label buys
    # are rare enough that caching one would only buy staleness. When the
    # mandatory contact fields cannot be assembled the purchase proceeds
    # without one, and carriers that insist reject with their own message.
    def buy(integration, stock_location, store, shipment_id, rate_id)
      buy_params = { rate: { id: rate_id } }
      end_shipper_id = end_shipper_id(integration, stock_location, store)
      buy_params[:end_shipper_id] = end_shipper_id if end_shipper_id.present?

      integration.client.shipment.buy(shipment_id, **buy_params)
    end

    def end_shipper_id(integration, stock_location, store)
      params = SpreeEasyPost.end_shipper_params(stock_location, store)
      return if params.nil?

      integration.client.end_shipper.create(**params).id
    rescue EasyPost::Errors::EasyPostError => e
      report(e, stock_location)
      nil
    end

    def label_purchase(shipment)
      rate = shipment.try(:selected_rate)
      postage_label = shipment.try(:postage_label)
      tracker = shipment.try(:tracker)

      Spree::LabelPurchase.new(
        external_id: shipment.id,
        carrier: carrier_key(rate&.carrier),
        service: rate&.service,
        tracking_number: shipment.tracking_code,
        tracking_url: tracker&.public_url,
        cost: rate&.rate.to_d,
        currency: rate&.currency,
        format: LABEL_FORMATS[postage_label&.label_file_type.to_s],
        file_url: postage_label&.label_url,
        metadata: {
          'easypost_tracker_id' => tracker&.id,
          'easypost_tracker_url' => tracker&.public_url,
          'easypost_rate_id' => rate&.id,
          'easypost_forms' => Array(shipment.try(:forms)).map { |form| { 'form_type' => form.try(:form_type), 'url' => form.try(:form_url) } }
        }.compact
      )
    end

    def carrier_key(carrier)
      return if carrier.blank?

      CARRIER_KEYS[carrier.to_s] || carrier.to_s
    end

    def refund_outcome(refund_status)
      case refund_status.to_s
      when 'refunded' then 'refunded'
      when 'rejected', 'not_applicable' then false
      else 'refund_requested'
      end
    end

    def report(error, subject)
      Rails.error.report(
        error,
        context: { subject_type: subject.class.name, subject_id: subject.try(:id) },
        source: 'spree_easypost.fulfillment'
      )
    end
  end
end
