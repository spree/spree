# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Company Self-Service API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }
  let(:company) { create(:company, store: store, name: 'Acme Industrial') }

  path '/api/v3/store/account/companies' do
    get 'List my company memberships' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the authenticated customer's company memberships, each with the node it
        is held on and the path of nodes above it. Standing covers the node and every
        node below it, so a membership on a parent authorizes buying for its divisions.
      DESC

      sdk_example 'account-companies/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true

      response '200', 'memberships listed' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].first['company']['name']).to eq('Acme Industrial')
        end
      end

      response '401', 'not authenticated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { nil }

        run_test!
      end
    end
  end

  path '/api/v3/store/companies/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Company node ID (comp_...)'

    get 'Get a company node' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns one node of the buyer's organization. Requires standing — a membership on
        the node or on one of its ancestors; any other node is not found rather than
        refused, so its existence is not disclosed.
      DESC

      sdk_example 'companies/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true

      response '200', 'company found' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let(:id) { company.prefixed_id }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Acme Industrial')
        end
      end

      response '404', 'no standing over this node' do
        let(:id) { company.prefixed_id }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test!
      end
    end

    patch 'Update a company node' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Renames the node. Structure — the parent and the kind — is managed by the merchant, not by buyers.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { name: { type: :string, example: 'Acme Industrial Group' } }
      }

      response '200', 'company updated' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let(:id) { company.prefixed_id }
        let(:body) { { name: 'Acme Industrial Group' } }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Acme Industrial Group')
        end
      end
    end
  end

  path '/api/v3/store/companies/{company_id}/members' do
    parameter name: :company_id, in: :path, type: :string, required: true, description: 'Company node ID (comp_...)'

    get 'List company members' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The people with standing over this node. Within a company every member may read and manage the directory.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true

      response '200', 'members listed' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let(:company_id) { company.prefixed_id }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].first['email']).to eq(user.email)
        end
      end
    end

    post 'Add a member by email' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Adds a person to the node by email. An email that already belongs to a customer of
        this store becomes a membership immediately (a `cmem_...` id); any other email
        becomes an invitation (a `cinv_...` id) and the invite email goes out.
      DESC

      sdk_example 'companies/members-create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { customer_email: { type: :string, example: 'colleague@acme.test' } },
        required: ['customer_email']
      }

      response '201', 'member added or invitation sent' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let!(:colleague) { create(:customer, email: 'colleague@acme.test') }
        let(:company_id) { company.prefixed_id }
        let(:body) { { customer_email: 'colleague@acme.test' } }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          expect(JSON.parse(response.body)['email']).to eq('colleague@acme.test')
        end
      end
    end
  end

  path '/api/v3/store/companies/{company_id}/addresses' do
    parameter name: :company_id, in: :path, type: :string, required: true, description: 'Company node ID (comp_...)'

    get 'List the company address book' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The labeled ship-to and bill-to sites this node owns. A node with no default of its own falls back to its nearest ancestor when prefilling checkout.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true

      response '200', 'addresses listed' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let!(:entry) { create(:company_address, company: company, label: 'Headquarters') }
        let(:company_id) { company.prefixed_id }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].first['label']).to eq('Headquarters')
        end
      end
    end
  end

  path '/api/v3/store/company_addresses/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Address book entry ID (caddr_...)'

    patch 'Update an address book entry' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Renames a site or moves the default ship-to or bill-to flag to it. Only one entry per node holds each default.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          label: { type: :string, example: 'Northern Warehouse' },
          default_shipping: { type: :boolean, example: true }
        }
      }

      response '200', 'address book entry updated' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let!(:entry) { create(:company_address, company: company, label: 'Headquarters') }
        let(:id) { entry.prefixed_id }
        let(:body) { { label: 'Northern Warehouse', default_shipping: true } }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          expect(JSON.parse(response.body)['label']).to eq('Northern Warehouse')
        end
      end
    end

    delete 'Remove an address book entry' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Takes the site out of the address book. Orders already placed to it keep their own copy of the address.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true

      response '204', 'address book entry removed' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let!(:entry) { create(:company_address, company: company, label: 'Headquarters') }
        let(:id) { entry.prefixed_id }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test!
      end
    end
  end

  path '/api/v3/store/company_invitations/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Invitation ID (cinv_...)'

    delete 'Revoke an invitation' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Withdraws a pending invitation, spending its token. Any member with standing over the node may revoke.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true

      response '204', 'invitation revoked' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let!(:invitation) { create(:company_invitation, company: company, email: 'pending@acme.test') }
        let(:id) { invitation.prefixed_id }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test!
      end
    end
  end

  path '/api/v3/store/companies/{company_id}/orders' do
    parameter name: :company_id, in: :path, type: :string, required: true, description: 'Company node ID (comp_...)'

    get 'List the company purchases' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Completed orders placed for this node and every node below it, so a parent sees what its divisions bought.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true

      response '200', 'orders listed' do
        let!(:membership) { create(:company_membership, company: company, customer: user) }
        let!(:order) do
          create(:completed_order_with_totals, store: store).tap { |o| o.update_columns(company_id: company.id) }
        end
        let(:company_id) { company.prefixed_id }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |o| o['id'] }).to include(order.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/store/company_invitations/{token}' do
    parameter name: :token, in: :path, type: :string, required: true, description: 'Plaintext invitation token from the invite email'

    get 'Look up an invitation' do
      tags 'Companies'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Shows what is being joined, so the acceptance page can render before the invitee
        has an account. Deliberately unauthenticated — the token from the email is the
        credential. Spent, revoked and expired tokens are not found.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true

      response '200', 'invitation found' do
        let!(:invitation) { create(:company_invitation, company: company, email: 'new@acme.test') }
        let(:token) { invitation.token }
        let(:'x-spree-api-key') { api_key.token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['company_name']).to eq('Acme Industrial')
          expect(data).not_to have_key('token')
        end
      end

      response '404', 'token spent, revoked or expired' do
        let(:token) { 'no-such-token' }
        let(:'x-spree-api-key') { api_key.token }

        run_test!
      end
    end
  end

  path '/api/v3/store/company_invitations/{token}/accept' do
    parameter name: :token, in: :path, type: :string, required: true, description: 'Plaintext invitation token from the invite email'

    post 'Accept an invitation' do
      tags 'Companies'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Turns the invitation into a membership. Send a registration payload to create the
        account — it is always created with the invited email — or call it authenticated as
        the customer who owns that email to bind the invitation to the existing account.
      DESC

      sdk_example 'company-invitations/accept'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          first_name: { type: :string, example: 'Ada' },
          last_name: { type: :string, example: 'Lovelace' },
          password: { type: :string, example: 'a-strong-password' },
          password_confirmation: { type: :string, example: 'a-strong-password' }
        }
      }

      response '201', 'membership created' do
        let!(:invitation) { create(:company_invitation, company: company, email: 'new@acme.test') }
        let(:token) { invitation.token }
        let(:body) do
          { first_name: 'Ada', password: 'a-strong-password', password_confirmation: 'a-strong-password' }
        end
        let(:'x-spree-api-key') { api_key.token }

        run_test! do |response|
          expect(JSON.parse(response.body)['email']).to eq('new@acme.test')
        end
      end
    end
  end
end
