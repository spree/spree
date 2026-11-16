module AdyenHelpers
  CHECKOUT_URL = 'https://checkout-test.adyen.com/v72'.freeze
  MANAGEMENT_URL = 'https://management-test.adyen.com/v3'.freeze

  # A payment a session settled, carrying the PSP reference settlement records.
  def adyen_session_payment(gateway:, status: 'pending', psp_reference: 'PSP0000000000001', amount: nil, order: nil)
    order ||= create(:order_with_line_items, store: gateway.store)
    session = create(:adyen_payment_session, owner: order, payment_method: gateway, amount: amount || order.total)
    create(:payment, order: order, payment_method: gateway, response_code: session.external_id, amount: amount || order.total,
                     status: status, source: nil, skip_source_requirement: true,
                     metadata: psp_reference ? { 'adyen_psp_reference' => psp_reference } : {})
  end

  def adyen_json(body, status: 200)
    { status: status, body: body.to_json, headers: { 'Content-Type' => 'application/json' } }
  end
end

RSpec.configure do |config|
  config.include AdyenHelpers
end

module AdyenWebhookHelpers
  HMAC_KEY = '44782DEF547AAA06C910C43932B1EB0C71FC68D9D0C057550C48EC2ACF6BA056'.freeze

  # A webhook body from spec/fixtures/webhooks, with the item's fields
  # overridden and signed with the given key.
  def adyen_webhook(name, hmac_key: HMAC_KEY, live: 'false', **overrides)
    body = JSON.parse(File.read(File.join(SpreeAdyen::Engine.root, 'spec', 'fixtures', 'webhooks', "#{name}.json")))
    body['live'] = live
    item = body['notificationItems'][0]['NotificationRequestItem']
    overrides.each do |key, value|
      if key.to_s == 'additionalData'
        item['additionalData'] = item['additionalData'].merge(value)
      else
        item[key.to_s] = value
      end
    end
    item['additionalData']['hmacSignature'] = Adyen::Utils::HmacValidator.new.calculate_webhook_hmac(item, hmac_key)
    body.to_json
  end
end

RSpec.configure do |config|
  config.include AdyenWebhookHelpers
end
