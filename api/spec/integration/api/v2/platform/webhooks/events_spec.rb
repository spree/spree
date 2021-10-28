require 'swagger_helper'
require 'spec_helper'

describe 'WebhooksEvents API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Webhook Event'
  options = {
    include_example: 'subscriber',
    filter_examples: [{ name: 'filter[execution_time]', example: 1_234 },
                      { name: 'filter[name]', example: 'order.canceled' },
                      { name: 'filter[request_errors]', example: "[SPREE WEBHOOKS] 'order.canceled' can not make a request to 'http://google.com/'" },
                      { name: 'filter[response_code]', example: '200' },
                      { name: 'filter[success]', example: true },
                      { name: 'filter[url]', example: 'http://google.com/' }]
  }
  
  let(:records_list) { create_list(:event, 2, :successful) }
  let(:event) { build(:event, :successful) }

  path '/api/v2/platform/webhooks/events' do
    include_examples 'GET records list', resource_name, options
  end
end
