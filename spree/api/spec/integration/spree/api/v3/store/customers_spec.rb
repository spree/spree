# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Customers API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  path '/api/v3/store/customer' do
    get 'Get current customer profile' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the profile of the currently authenticated customer'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer JWT token'

      response '200', 'profile found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/StoreCustomer'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq(user.email)
        end
      end

      response '401', 'unauthorized - no token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '401', 'unauthorized - invalid token' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { 'Bearer invalid_token' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update current customer profile' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates the profile of the currently authenticated customer'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string, example: 'John' },
          last_name: { type: :string, example: 'Doe' },
          email: { type: :string, format: 'email', example: 'customer@example.com' },
          password: { type: :string, example: 'newpassword123' },
          password_confirmation: { type: :string, example: 'newpassword123' },
          accepts_email_marketing: { type: :boolean, example: true },
          phone: { type: :string, example: '+1 555 123 4567' }
        }
      }

      response '200', 'profile updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { first_name: 'Updated', last_name: 'Name' } }

        schema '$ref' => '#/components/schemas/StoreCustomer'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['first_name']).to eq('Updated')
          expect(data['last_name']).to eq('Name')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { email: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
