require 'swagger_helper'
require 'spec_helper'

# [TODO]: move
FactoryBot.define do
  factory :webhook_subscriber, aliases: [:subscriber], class: Spree::Webhooks::Subscriber do
    trait :active do
      active { true }
      sequence(:url) { |n| "https://www.url#{n}.com/" }
    end
  end
end


describe 'WebhooksSubscribers API', swagger: true do
  include_context 'Platform API v2'

  resource_name = 'WebhookSubscriber'
  options = {}
  
  let(:id) { subscriber.tap(&:save).id }
  let(:invalid_param_value) { { url: '' } }
  let(:records_list) { create_list(:subscriber, 2, :active, subscriptions: ['*']) }
  let(:subscriber) { build(:subscriber, :active, subscriptions: ['*']) }
  let(:valid_create_param_value) { subscriber.attributes }

  path '/api/v2/platform/webhooks/subscribers' do
    include_examples 'GET records list', resource_name, options
    include_examples 'POST create record', resource_name, options
  end

  path '/api/v2/platform/webhooks/subscribers/{id}' do
    include_examples 'GET record', resource_name, options
  end
end
