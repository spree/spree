# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Customers API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:existing_user) { create(:user, email: 'existing@example.com', password: 'password123') }

  path '/api/v3/store/customers' do
    post 'Register a new customer' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description 'Creates a new customer account and returns a JWT token'

      sdk_example <<~JS
        const auth = await client.customers.create({
          email: 'newuser@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          first_name: 'John',
          last_name: 'Doe',
          phone: '+1234567890',
          accepts_email_marketing: true,
          metadata: { source: 'storefront' },
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'newuser@example.com' },
          password: { type: :string, minLength: 6, example: 'password123' },
          password_confirmation: { type: :string, example: 'password123' },
          first_name: { type: :string, example: 'John' },
          last_name: { type: :string, example: 'Doe' },
          phone: { type: :string, example: '+1234567890' },
          accepts_email_marketing: { type: :boolean, example: true },
          metadata: { type: :object, example: { source: 'storefront' } }
        },
        required: %w[email password]
      }

      response '201', 'registration successful' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) do
          {
            email: 'newuser@example.com',
            password: 'password123',
            first_name: 'John',
            last_name: 'Doe',
            phone: '+1234567890',
            accepts_email_marketing: true,
            metadata: { source: 'storefront' }
          }
        end

        schema '$ref' => '#/components/schemas/AuthResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['token']).to be_present
          expect(data['user']).to be_present

          # Verify user was created with all fields
          new_user = Spree.user_class.find_by(email: 'newuser@example.com')
          expect(new_user).to be_present
          expect(new_user.first_name).to eq('John')
          expect(new_user.phone).to eq('+1234567890')
          expect(new_user.accepts_email_marketing).to eq(true)
          expect(new_user.metadata).to eq({ 'source' => 'storefront' })
        end
      end

      response '422', 'email already taken' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) do
          {
            email: existing_user.email,
            password: 'password123'
          }
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('validation_error')
        end
      end
    end
  end

  path '/api/v3/store/customer' do
    get 'Get current customer profile' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns the profile of the currently authenticated customer'

      sdk_example <<~JS
        const customer = await client.customer.get({
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer JWT token'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., name,slug,price). id is always included.'

      response '200', 'profile found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/Customer'

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

      sdk_example <<~JS
        const customer = await client.customer.update({
          first_name: 'John',
          last_name: 'Doe',
          metadata: { preferred_contact: 'email' },
        }, {
          bearerToken: '<token>',
        })
      JS

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
          phone: { type: :string, example: '+1 555 123 4567' },
          metadata: { type: :object, example: { preferred_contact: 'email' } }
        }
      }

      response '200', 'profile updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { first_name: 'Updated', last_name: 'Name' } }

        schema '$ref' => '#/components/schemas/Customer'

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
