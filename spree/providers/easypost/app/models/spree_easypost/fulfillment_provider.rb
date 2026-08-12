module SpreeEasyPost
  # Buys the EasyPost label when a fulfillment ships and refunds it on
  # cancel. Runs inside the fulfillment state transition, so nothing here
  # may raise — a purchase failure is reported and the fulfillment proceeds
  # without a label (the admin buys one manually, exactly as with the
  # Manual provider).
  class FulfillmentProvider < Spree::FulfillmentProvider::Base
    def self.integration_class
      'SpreeEasyPost::Integration'
    end

    def self.provider_name
      SpreeEasyPost::PROVIDER_NAME
    end

    def self.generates_labels?
      true
    end

    # Buys the rate quoted at checkout when it is still valid; EasyPost
    # quotes expire, so a stale or missing quote is re-quoted from the
    # actual fulfillment and bought only when a rate for the exact
    # carrier/service the customer selected comes back — silently shipping a
    # different service than the customer paid for is worse than no label.
    def create_fulfillment(fulfillment)
      # Idempotent: a label bought through the explicit buy-label step must
      # not be bought again when the fulfillment is later marked fulfilled.
      if fulfillment.metadata['easypost_purchased_shipment_id'].present?
        return {
          tracking_number: fulfillment.tracking,
          tracking_url: fulfillment.metadata['easypost_tracker_url']
        }
      end

      integration = integration_for(fulfillment)
      return {} if integration.nil?

      shipment = buy_quoted(integration, fulfillment) || requote_and_buy(integration, fulfillment)
      return {} if shipment.nil?

      remember_purchase(fulfillment, shipment)
      { tracking_number: shipment.tracking_code, tracking_url: shipment.tracker&.public_url }
    rescue StandardError => e
      report(e, fulfillment)
      {}
    end

    # Files a refund request for the purchased label. Refund failures never
    # block the cancellation — the money side is between the merchant and
    # EasyPost, the stock side must proceed regardless.
    def cancel_fulfillment(fulfillment)
      integration = integration_for(fulfillment)
      purchased_id = fulfillment.metadata['easypost_purchased_shipment_id']
      return true if integration.nil? || purchased_id.blank?

      integration.client.shipment.refund(purchased_id)
      true
    rescue StandardError => e
      report(e, fulfillment)
      false
    end

    def tracking_url(fulfillment)
      fulfillment.metadata['easypost_tracker_url']
    end

    def documents(fulfillment)
      label_url = fulfillment.metadata['easypost_label_url']
      return [] if label_url.blank?

      [{ kind: 'label', url: label_url }]
    end

    private

    def buy_quoted(integration, fulfillment)
      quoted = fulfillment.selected_delivery_rate&.metadata || {}
      shipment_id = quoted['easypost_shipment_id']
      rate_id = quoted['easypost_rate_id']
      return if shipment_id.blank? || rate_id.blank?

      integration.client.shipment.buy(shipment_id, rate: { id: rate_id })
    rescue EasyPost::Errors::EasyPostError
      nil
    end

    def requote_and_buy(integration, fulfillment)
      # The selected rate carries the carrier service the customer chose —
      # the delivery method no longer pins one (it offers many).
      selected = fulfillment.selected_delivery_rate
      address = fulfillment.address || fulfillment.order&.ship_address
      return if selected&.carrier.blank? || selected.service_level.blank? || address.nil?

      shipment = integration.client.shipment.create(
        from_address: address_params(fulfillment.stock_location),
        to_address: address_params(address),
        parcel: requote_parcel(fulfillment)
      )
      rate = shipment.rates.find do |candidate|
        candidate.carrier == selected.carrier && candidate.service == selected.service_level
      end
      return if rate.nil?

      integration.client.shipment.buy(shipment.id, rate: { id: rate.id })
    end

    def requote_parcel(fulfillment)
      SpreeEasyPost.parcel_params(fulfillment.to_package, fulfillment.order&.store)
    end

    def remember_purchase(fulfillment, shipment)
      fulfillment.update_columns(
        metadata: fulfillment.metadata.merge(
          'easypost_purchased_shipment_id' => shipment.id,
          'easypost_label_url' => shipment.postage_label&.label_url,
          'easypost_tracker_url' => shipment.tracker&.public_url
        )
      )
    end

    def address_params(source)
      SpreeEasyPost.address_params(source)
    end

    def report(error, fulfillment)
      Rails.error.report(error, context: { fulfillment_id: fulfillment.id }, source: 'spree_easypost.fulfillment')
    end
  end
end
