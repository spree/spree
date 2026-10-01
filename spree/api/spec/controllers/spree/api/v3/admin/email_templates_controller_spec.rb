require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::EmailTemplatesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'
  include_context 'with an editable email template'

  let(:id) { editable_key.tr('/', '.') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists every editable template, Spree default or the store version' do
      create(:email_template, store: store, key: editable_key, locale: 'de', body: 'German')

      get :index, as: :json

      entry = json_response['data'].find { |template| template['id'] == id }
      expect(entry).to include('kind' => 'email', 'language' => 'any', 'customized' => false, 'customized_languages' => ['de'])
      expect(entry['body']).to eq(entry['default_body'])
      expect(json_response['data'].map { |template| template['id'] }).not_to include('spree.webhook_mailer.endpoint_disabled')
    end
  end

  describe 'GET #show' do
    it "returns the store's published version, the draft and whether the default moved on" do
      create(:email_template, store: store, key: editable_key, body: 'Published', base_body: 'An older default')
      create(:email_template_draft, store: store, key: editable_key, body: 'Draft', base_body: 'An older default', updated_by: admin_user)

      get :show, params: { id: id, expand: 'draft.updated_by' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('customized' => true, 'body' => 'Published', 'default_changed' => true, 'base_body' => 'An older default')
      expect(json_response['draft']).to include('body' => 'Draft', 'lock_version' => 0, 'updated_by_type' => 'admin_user')
      expect(json_response['draft']['updated_by']['label']).to be_present
    end

    it "writes Spree's translation keys out as text for one language" do
      get :show, params: { id: id, language: 'en' }, as: :json

      expect(json_response['body']).not_to include("| t")
      expect(json_response['body']).to include(Spree.t('admin_user_mailer.password_reset_email.action'))
      expect(json_response['default_body']).to eq(json_response['body'])
    end

    it 'shows the version for every language, saying so, when one language has none of its own' do
      create(:email_template, store: store, key: editable_key, body: 'For everyone')

      get :show, params: { id: id, language: 'de' }, as: :json

      expect(json_response).to include('body' => 'For everyone', 'customized' => true, 'published_language' => 'any')
    end

    it 'reads the version for the language asked for' do
      create(:email_template, store: store, key: editable_key, locale: 'de', body: 'German')

      get :show, params: { id: id, language: 'de' }, as: :json

      expect(json_response).to include('language' => 'de', 'body' => 'German')
    end

    it 'does not find a template merchants may not edit' do
      get :show, params: { id: 'spree.webhook_mailer.endpoint_disabled' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "never reads another store's version" do
      create(:email_template, store: create(:store), key: editable_key, body: 'Theirs')

      get :show, params: { id: id }, as: :json

      expect(json_response['customized']).to be(false)
    end
  end

  describe 'DELETE #destroy' do
    it "goes back to Spree's default, keeping the history" do
      template = create(:email_template, store: store, key: editable_key, body: 'Published')
      create(:email_template_revision, email_template: template)

      delete :destroy, params: { id: id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['customized']).to be(false)
      expect(template.reload).to be_reverted
      expect(template.revisions.count).to eq(1)
    end
  end

  context 'with a secret key lacking the email templates scope' do
    let(:headers) { { 'x-spree-api-key' => create(:api_key, :secret, store: store, scopes: %w[read_settings]).plaintext_token } }

    it 'is refused' do
      get :index, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
