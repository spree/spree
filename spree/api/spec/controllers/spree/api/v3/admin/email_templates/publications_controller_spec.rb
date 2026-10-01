require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::EmailTemplates::PublicationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'
  include_context 'with an editable email template'

  let(:id) { editable_key.tr('/', '.') }
  let(:body) { '<mj-section><mj-column><mj-text>Hi {{ user.first_name }}</mj-text></mj-column></mj-section>' }

  before { request.headers.merge!(headers) }

  it 'makes the draft live' do
    create(:email_template_draft, store: store, key: editable_key, body: body)

    post :create, params: { email_template_id: id }, as: :json

    expect(response).to have_http_status(:created)
    expect(json_response).to include('customized' => true, 'body' => body, 'draft' => nil)
  end

  it 'refuses a draft that does not render, with each problem and its line' do
    create(:email_template_draft, store: store, key: editable_key, body: "<mj-section>\n<mj-column><mj-text>{{ user.nickname }}</mj-text></mj-column></mj-section>")

    post :create, params: { email_template_id: id }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response['error']['code']).to eq('email_template_invalid')
    expect(json_response['error']['details']['problems']).to contain_exactly(
      hash_including('email' => id, 'line' => 2, 'message' => a_string_including('nickname'))
    )
    expect(store.email_templates.count).to eq(0)
  end

  it 'refuses when there is no draft' do
    post :create, params: { email_template_id: id }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end
end
