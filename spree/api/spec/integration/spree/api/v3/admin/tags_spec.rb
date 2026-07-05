# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Tags API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/tags' do
    get 'List tags' do
      tags 'Settings'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns tag names for a given taggable type. Used for autocomplete in tag inputs on products, orders, and customers.'

      admin_sdk_example 'tags/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :taggable_type, in: :query, type: :string, required: true,
                description: 'Taggable type (`Spree::Product`, `Spree::Order`, or `Spree::User`)'
      parameter name: :q, in: :query, type: :string, required: false,
                description: 'Optional case-insensitive substring filter'

      response '200', 'tags found' do
        let(:taggable_type) { Spree.user_class.to_s }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before do
          user = create(:user)
          user.tag_list.add('vip', 'wholesale')
          user.save!
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          names = data['data'].map { |t| t['name'] }
          expect(names).to include('vip', 'wholesale')
        end
      end

      response '422', 'invalid taggable type' do
        let(:taggable_type) { 'Spree::Foo' }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_taggable_type')
        end
      end
    end
  end
end
