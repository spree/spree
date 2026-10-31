module PaypalHelpers
  PaypalResponse = Struct.new(:status_code, :raw_body, :headers)

  # An error PayPal answers with, as the SDK raises it.
  def paypal_error(issue, description = 'PayPal refused the request.', status: 422)
    body = {
      name: 'UNPROCESSABLE_ENTITY',
      message: 'The requested action could not be performed.',
      details: [{ issue: issue, description: description }]
    }.to_json
    PaypalServerSdk::ErrorException.new('refused', PaypalResponse.new(status, body, {}))
  end

  # A PayPal order as PaypalServerSdk models serialize it.
  def paypal_order_data(id: 'ORDER1234567890AB', status: 'COMPLETED', captures: nil, authorizations: nil, extra: {})
    payments = { 'captures' => captures, 'authorizations' => authorizations }.compact
    {
      'id' => id,
      'status' => status,
      'purchase_units' => [
        {
          'amount' => { 'currency_code' => 'USD', 'value' => '10.00' },
          'payments' => payments.presence
        }.compact
      ]
    }.merge(extra)
  end

  def paypal_capture(id: 'CAPTURE123456789A', status: 'COMPLETED', reason: nil, value: '10.00')
    {
      'id' => id,
      'status' => status,
      'status_details' => (reason ? { 'reason' => reason } : nil),
      'amount' => { 'currency_code' => 'USD', 'value' => value }
    }.compact
  end

  def paypal_authorization(id: 'AUTHORIZ123456789', status: 'CREATED', value: '10.00')
    { 'id' => id, 'status' => status, 'amount' => { 'currency_code' => 'USD', 'value' => value } }
  end
end

RSpec.configure do |config|
  config.include PaypalHelpers
end
