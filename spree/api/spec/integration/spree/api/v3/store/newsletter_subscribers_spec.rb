# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Newsletter Subscribers API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  path '/api/v3/store/newsletter_subscribers' do
    post 'Subscribe an email address to the newsletter' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates or reuses a newsletter subscriber for the current store and returns a generic accepted response.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Optional Bearer JWT token for an authenticated customer'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'subscriber@example.com' }
        },
        required: ['email']
      }

      response '202', 'subscription accepted' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { nil }
        let(:body) { { email: 'subscriber@example.com' } }

        schema type: :object,
               properties: {
                 message: { type: :string, example: 'If that email can be subscribed, the request has been processed.' }
               },
               required: ['message']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['message']).to be_present
          expect(Spree::NewsletterSubscriber.find_by(email: 'subscriber@example.com', store: store)).to be_present
        end
      end

      response '422', 'invalid email' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { nil }
        let(:body) { { email: 'not-an-email' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('validation_error')
        end
      end
    end
  end
end
