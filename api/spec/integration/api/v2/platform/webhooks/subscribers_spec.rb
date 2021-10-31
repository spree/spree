require 'swagger_helper'
require 'spec_helper'

describe 'WebhooksSubscribers API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Webhook Subscriber'
  options = {
    include_examples: 'events',
    filter_examples: [{ name: 'filter[active_eq]', example: 'true' },
                      { name: 'filter[url_cont]', example: 'mysite' }]
  }

  let(:id) { subscriber.tap(&:save).id }
  let(:invalid_param_value) { { url: '' } }
  let(:records_list) { create_list(:subscriber, 2, :active, subscriptions: ['*']) }
  let(:subscriber) { build(:subscriber, :active, subscriptions: ['*']) }
  let(:valid_create_param_value) { subscriber.attributes }
  let(:valid_update_param_value) { { active: true } }

  path '/api/v2/platform/webhooks/subscribers' do
    include_examples 'GET records list', resource_name, options
    include_examples 'POST create record', resource_name, options
  end

  path '/api/v2/platform/webhooks/subscribers/{id}' do
    include_examples 'GET record', resource_name, options
    include_examples 'PATCH update record', resource_name, options
    include_examples 'DELETE record', resource_name, options
  end
end
