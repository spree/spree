require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::EmailTemplates::DraftsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'
  include_context 'with an editable email template'

  let(:id) { editable_key.tr('/', '.') }

  before { request.headers.merge!(headers) }

  describe 'PUT #update' do
    it 'saves the draft, leaving what customers receive alone' do
      put :update, params: { email_template_id: id, subject: 'New subject', body: '<mj-section></mj-section>' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['customized']).to be(false)
      expect(json_response['draft']).to include('subject' => 'New subject', 'body' => '<mj-section></mj-section>')
      expect(store.email_template_drafts.first.updated_by).to eq(admin_user)
    end

    it 'saves a version for one language' do
      put :update, params: { email_template_id: id, language: 'de', body: 'German draft' }, as: :json

      expect(store.email_template_drafts.first.locale).to eq('de')
    end

    it 'refuses a save from a stale copy with 409, naming who saved last' do
      create(:email_template_draft, store: store, key: editable_key, body: 'Theirs', updated_by: create(:admin_user, first_name: 'Maria', last_name: 'Lopez'))
      store.email_template_drafts.first.update!(body: 'Theirs again')

      put :update, params: { email_template_id: id, body: 'Mine', lock_version: 0 }, as: :json

      expect(response).to have_http_status(:conflict)
      expect(json_response['error']['code']).to eq('email_template_stale')
      expect(json_response['error']['message']).to include('Maria')
      expect(store.email_template_drafts.first.body).to eq('Theirs again')
    end

    it 'refuses a language code that is not one' do
      put :update, params: { email_template_id: id, language: 'not a language', body: 'x' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'discards the draft' do
      create(:email_template_draft, store: store, key: editable_key)

      delete :destroy, params: { email_template_id: id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['draft']).to be_nil
      expect(store.email_template_drafts.count).to eq(0)
    end
  end
end
