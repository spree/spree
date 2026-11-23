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
