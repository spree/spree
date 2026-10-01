require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::EmailTemplates::TestEmailsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'
  include_context 'with an editable email template'

  let(:id) { editable_key.tr('/', '.') }

  before { request.headers.merge!(headers) }

  it 'sends the rendered template to the signed-in admin only' do
    expect do
      post :create, params: { email_template_id: id, to: 'someone@example.com', body: '<mj-section><mj-column><mj-text>Test</mj-text></mj-column></mj-section>' }, as: :json
    end.to have_enqueued_mail(Spree::EmailTemplateMailer, :test_email).with(store, admin_user.email, editable_key, hash_including(body: a_string_including('Test')))

    expect(response).to have_http_status(:accepted)
    expect(json_response['sent_to']).to eq(admin_user.email)
  end

  it 'sends nothing for a template that does not render' do
    expect do
      post :create, params: { email_template_id: id, body: '{{ user.nickname }}' }, as: :json
    end.not_to have_enqueued_mail

    expect(response).to have_http_status(:unprocessable_content)
  end

  context 'with a secret key, which has no inbox' do
    let(:headers) { api_key_headers }

    it 'refuses' do
      post :create, params: { email_template_id: id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
