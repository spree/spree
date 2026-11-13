require 'net/http'

# Tells the fulfilment partner about every placed order. Runs as a background
# job (the subscriber default), so a partner outage never fails checkout.
class OrderSyncSubscriber < Spree::Subscriber
  subscribes_to 'order.placed'

  def handle(event)
    url = ENV['ORDER_SYNC_URL']
    return if url.blank?

    order = Spree::Order.find_by_prefix_id(event.payload['id'])
    return unless order

    response = Net::HTTP.post(URI(url), payload(order).to_json, 'Content-Type' => 'application/json')
    return if response.is_a?(Net::HTTPSuccess)

    Rails.logger.warn("[order sync] #{order.number}: partner answered #{response.code}")
  rescue StandardError => e
    Rails.error.report(e, handled: true, context: { order: event.payload['id'] })
  end

  private

  def payload(order)
    {
      id: order.prefixed_id,
      number: order.number,
      total: order.total.to_s('F'),
      currency: order.currency
    }
  end
end
