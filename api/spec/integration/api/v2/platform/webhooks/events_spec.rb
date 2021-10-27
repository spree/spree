require 'swagger_helper'
require 'spec_helper'

describe 'WebhooksEvents API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'Webhook Event'
  options = {}
  
  let(:records_list) { create_list(:event, 2, :successful) }
  let(:event) { build(:event, :successful) }

  path '/api/v2/platform/webhooks/events' do
    include_examples 'GET records list', resource_name, options
  end
end
