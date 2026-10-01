require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::EmailTemplates::PreviewsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'
  include_context 'with an editable email template'

  let(:id) { editable_key.tr('/', '.') }

  before { request.headers.merge!(headers) }

  it 'renders unsaved changes with sample data and returns the variables used' do
    post :create, params: {
      email_template_id: id, subject: 'Hi {{ user.first_name }}',
      body: '<mj-section><mj-column><mj-text>For {{ user.email }}</mj-text></mj-column></mj-section>'
    }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response).to include('subject' => 'Hi Ann', 'email_key' => id)
    expect(json_response['html']).to include('For ann@example.com')
    expect(json_response['text']).to include('For ann@example.com')
    expect(json_response['variables']['user']).to include('first_name' => 'Ann')
  end

  it 'previews unsaved branding without saving it' do
    post :create, params: { email_template_id: id, branding: { card_color: '#123456', font: 'georgia' } }, as: :json

    expect(json_response['html']).to include('#123456', 'Georgia')
    expect(json_response['variables']['store']['branding']).to include('card_color' => '#123456')
    expect(store.reload.preferred_email_card_color).to be_nil
  end

  context 'when the sample shows records the caller may not read' do
    let(:headers) { { 'x-spree-api-key' => create(:api_key, :secret, store: store, scopes: scopes).plaintext_token } }

    before { allow(Spree::TestingSupport::EmailTemplateSample).to receive(:required_permissions).and_return(%w[read_orders]) }

    context 'with only the email templates scope' do
      let(:scopes) { %w[write_email_templates] }

      it 'is refused' do
        post :create, params: { email_template_id: id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['details']['required_scope']).to eq('read_orders')
      end
    end

    context 'with the orders scope too' do
      let(:scopes) { %w[write_email_templates read_orders] }

      it 'renders' do
        post :create, params: { email_template_id: id }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end
  end

  it 'marks text the email would not show on its line' do
    post :create, params: { email_template_id: id, body: "<mj-section><mj-column><mj-text>Hi</mj-text></mj-column></mj-section>\ntesting preview" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response['error']['details']['problems'].first).to include('email' => id, 'line' => 2, 'message' => a_string_including('testing preview'))
  end

  it 'says what is wrong and where when the template does not render' do
    post :create, params: { email_template_id: id, body: "<mj-section>\n{% if %}</mj-section>" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response['error']['details']['problems'].first).to include('email' => id, 'line' => 2)
  end

  it 'says so when the store has nothing to preview with' do
    allow(Spree::TestingSupport::EmailTemplateSample).to receive(:new).
      and_raise(Spree::EmailTemplates::NoSampleRecord, 'There is no order in this store to preview this email with yet.')

    post :create, params: { email_template_id: id }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response['error']).to include('code' => 'email_template_no_sample', 'message' => a_string_including('no order'))
  end
end
