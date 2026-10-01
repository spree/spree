# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Email Templates API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'
  include_context 'with an editable email template'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:id) { editable_key.tr('/', '.') }
  let(:email_template_id) { id }
  let(:body_mjml) { '<mj-section><mj-column><mj-text>Hi {{ user.first_name }}</mj-text></mj-column></mj-section>' }

  shared_context 'with admin auth parameters' do
    parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
    parameter name: :Authorization, in: :header, type: :string, required: true,
              description: 'Bearer token for admin authentication'
  end

  path '/api/v3/admin/email_templates' do
    get 'List email templates' do
      tags 'Email Templates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns every email template merchants may edit: the emails customers
        receive, the email layout and the shared partials. Each shows what
        customers receive now (the store's published version, else Spree's
        default) and any draft in progress. Staff emails are not editable.
      DESC
      admin_scope :read, :email_templates

      admin_sdk_example 'email-templates/list'

      include_context 'with admin auth parameters'
      parameter name: :language, in: :query, type: :string, required: false,
                description: 'A language code, or `any` (the default) for the version every language uses'

      response '200', 'email templates found' do
        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |template| template['id'] }).to include(id)
        end
      end
    end
  end

  path '/api/v3/admin/email_templates/{id}' do
    parameter name: :id, in: :path, type: :string, required: true,
              description: 'The template key with dots, e.g. `spree.order_mailer.confirm_email`'

    get 'Get an email template' do
      tags 'Email Templates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the template for one language: what customers receive now,
        Spree's default, and the draft with its `lock_version`. When Spree's
        default changed since the store's version started from it,
        `default_changed` is true and `base_body` holds the default it
        started from, to compare with `default_body`.
      DESC
      admin_scope :read, :email_templates

      admin_sdk_example 'email-templates/get'

      include_context 'with admin auth parameters'
      parameter name: :language, in: :query, type: :string, required: false,
                description: 'A language code, or `any` (the default)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (`draft.updated_by`)'

      response '200', 'email template found' do
        schema '$ref' => '#/components/schemas/EmailTemplate'

        before { create(:email_template_draft, store: store, key: editable_key, body: body_mjml, updated_by: admin_user) }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(id)
          expect(data['draft']['body']).to eq(body_mjml)
        end
      end

      response '404', 'not an editable template' do
        let(:id) { 'spree.webhook_mailer.endpoint_disabled' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete "Revert an email template to Spree's default" do
      tags 'Email Templates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Goes back to Spree's default for one language and discards the draft.
        The store's published versions are kept, so one can still be restored.
      DESC
      admin_scope :write, :email_templates

      admin_sdk_example 'email-templates/revert'

      include_context 'with admin auth parameters'
      parameter name: :language, in: :query, type: :string, required: false,
                description: 'A language code, or `any` (the default)'

      response '200', 'email template reverted' do
        schema '$ref' => '#/components/schemas/EmailTemplate'

        before { create(:email_template, store: store, key: editable_key, body: body_mjml) }

        run_test! do |response|
          expect(JSON.parse(response.body)['customized']).to be(false)
        end
      end
    end
  end

  path '/api/v3/admin/email_templates/{email_template_id}/draft' do
    parameter name: :email_template_id, in: :path, type: :string, required: true,
              description: 'The template key with dots'

    put 'Save an email template draft' do
      tags 'Email Templates'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Saves the draft, in any state; customers keep receiving the published
        version until it is published. Send the `lock_version` the draft was
        loaded with: a save made from an older copy is refused with 409,
        naming who saved last. The first save starts from what is published,
        else Spree's default.
      DESC
      admin_scope :write, :email_templates

      admin_sdk_example 'email-templates/save-draft'

      include_context 'with admin auth parameters'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          language: { type: :string, example: 'any' },
          subject: { type: :string, example: 'Reset your {{ store.name }} password' },
          body: { type: :string, example: '<mj-section><mj-column><mj-text>Hi {{ user.first_name }}</mj-text></mj-column></mj-section>' },
          lock_version: { type: :integer, example: 0 }
        }
      }

      response '200', 'draft saved' do
        let(:body) { { subject: 'Reset your {{ store.name }} password', body: body_mjml } }

        schema '$ref' => '#/components/schemas/EmailTemplate'

        run_test! do |response|
          expect(JSON.parse(response.body)['draft']['lock_version']).to eq(0)
        end
      end

      response '409', 'saved by someone else since it was loaded' do
        let(:body) { { body: body_mjml, lock_version: 0 } }

        before do
          draft = create(:email_template_draft, store: store, key: editable_key, updated_by: admin_user)
          draft.update!(body: 'Saved again')
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Discard an email template draft' do
      tags 'Email Templates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :write, :email_templates

      admin_sdk_example 'email-templates/discard-draft'

      include_context 'with admin auth parameters'
      parameter name: :language, in: :query, type: :string, required: false,
                description: 'A language code, or `any` (the default)'

      response '200', 'draft discarded' do
        schema '$ref' => '#/components/schemas/EmailTemplate'

        before { create(:email_template_draft, store: store, key: editable_key) }

        run_test! do |response|
          expect(JSON.parse(response.body)['draft']).to be_nil
        end
      end
    end
  end

  path '/api/v3/admin/email_templates/{email_template_id}/publication' do
    parameter name: :email_template_id, in: :path, type: :string, required: true,
              description: 'The template key with dots'

    post 'Publish an email template draft' do
      tags 'Email Templates'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Makes the draft what customers receive. The draft is first rendered
        with sample data; one that does not render (for the layout or a
        partial: in any email using it) is refused with 422, listing each
        problem with its email and line.
      DESC
      admin_scope :write, :email_templates

      admin_sdk_example 'email-templates/publish'

      include_context 'with admin auth parameters'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: { language: { type: :string, example: 'any' } }
      }

      response '201', 'draft published' do
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/EmailTemplate'

        before { create(:email_template_draft, store: store, key: editable_key, body: body_mjml) }

        run_test! do |response|
          expect(JSON.parse(response.body)['customized']).to be(true)
        end
      end

      response '422', 'the draft does not render' do
        let(:body) { {} }

        before { create(:email_template_draft, store: store, key: editable_key, body: '{{ user.nickname }}') }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          problems = JSON.parse(response.body)['error']['details']['problems']
          expect(problems.first['message']).to include('nickname')
        end
      end
    end
  end

  path '/api/v3/admin/email_templates/{email_template_id}/preview' do
    parameter name: :email_template_id, in: :path, type: :string, required: true,
              description: 'The template key with dots'

    post 'Preview an email template' do
      tags 'Email Templates'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Renders the template with sample data built from the store's latest
        matching record, or the one `record_id` names, and returns the email
        with the variables it was rendered with. An unsaved `subject` and
        `body` take the place of the current version. The layout and partials
        render inside an email, `email_key` or the first one.
      DESC
      admin_scope :write, :email_templates

      admin_sdk_example 'email-templates/preview'

      include_context 'with admin auth parameters'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          language: { type: :string, example: 'any' },
          subject: { type: :string, example: 'Reset your {{ store.name }} password' },
          body: { type: :string, example: '<mj-section><mj-column><mj-text>Hi {{ user.first_name }}</mj-text></mj-column></mj-section>' },
          record_id: { type: :string, example: 'or_m3Rp9wXz', description: 'The record to build sample data from' },
          email_key: { type: :string, example: 'spree.order_mailer.confirm_email', description: 'For the layout or a partial, the email to show it in' }
        }
      }

      response '200', 'email template rendered' do
        let(:body) { { body: body_mjml } }

        schema '$ref' => '#/components/schemas/EmailTemplatePreview'

        run_test! do |response|
          expect(JSON.parse(response.body)['html']).to include('Hi Ann')
        end
      end
    end
  end

  path '/api/v3/admin/email_templates/{email_template_id}/test_email' do
    parameter name: :email_template_id, in: :path, type: :string, required: true,
              description: 'The template key with dots'

    post 'Send a test email' do
      tags 'Email Templates'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Sends the template, rendered as the preview renders it, to the
        signed-in admin, and never to another address: the sample data comes
        from a real customer's records. Takes the same body as the preview.
      DESC
      admin_scope :write, :email_templates

      admin_sdk_example 'email-templates/send-test'

      include_context 'with admin auth parameters'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          language: { type: :string, example: 'any' },
          subject: { type: :string },
          body: { type: :string },
          record_id: { type: :string },
          email_key: { type: :string }
        }
      }

      response '202', 'test email queued' do
        let(:body) { { body: body_mjml } }

        schema type: :object, properties: { sent_to: { type: :string } }, required: %w[sent_to]

        run_test! do |response|
          expect(JSON.parse(response.body)['sent_to']).to eq(admin_user.email)
        end
      end
    end
  end

  path '/api/v3/admin/email_templates/{email_template_id}/revisions' do
    parameter name: :email_template_id, in: :path, type: :string, required: true,
              description: 'The template key with dots'

    get 'List email template revisions' do
      tags 'Email Templates'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Every version of the template published in one language, newest
        first. Reverting to Spree's default keeps them.
      DESC
      admin_scope :read, :email_templates

      admin_sdk_example 'email-templates/revisions/list'

      include_context 'with admin auth parameters'
      parameter name: :language, in: :query, type: :string, required: false,
                description: 'A language code, or `any` (the default)'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (`published_by`)'

      response '200', 'revisions found' do
        before do
          template = create(:email_template, store: store, key: editable_key)
          create(:email_template_revision, email_template: template, published_by: admin_user)
        end

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].size).to eq(1)
        end
      end
    end
  end

  path '/api/v3/admin/email_templates/{email_template_id}/revisions/{revision_id}/restoration' do
    parameter name: :email_template_id, in: :path, type: :string, required: true,
              description: 'The template key with dots'
    parameter name: :revision_id, in: :path, type: :string, required: true

    post 'Restore an email template revision' do
      tags 'Email Templates'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Copies the revision into the draft, to be published like any change.
        Send the draft's `lock_version` when one is open, as when saving it.
      DESC
      admin_scope :write, :email_templates

      admin_sdk_example 'email-templates/revisions/restore'

      include_context 'with admin auth parameters'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          language: { type: :string, example: 'any' },
          lock_version: { type: :integer }
        }
      }

      response '201', 'revision copied into the draft' do
        let(:template) { create(:email_template, store: store, key: editable_key) }
        let(:revision_id) { create(:email_template_revision, email_template: template, body: body_mjml).prefixed_id }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/EmailTemplate'

        run_test! do |response|
          expect(JSON.parse(response.body)['draft']['body']).to eq(body_mjml)
        end
      end
    end
  end
end
