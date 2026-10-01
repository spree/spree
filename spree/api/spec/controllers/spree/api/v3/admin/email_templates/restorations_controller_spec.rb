require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::EmailTemplates::RestorationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'
  include_context 'with an editable email template'

  let(:id) { editable_key.tr('/', '.') }
  let(:template) { create(:email_template, store: store, key: editable_key) }
  let(:revision) { create(:email_template_revision, email_template: template, subject: 'Old subject', body: 'Old body') }

  before { request.headers.merge!(headers) }

  it 'copies the revision into the draft' do
    post :create, params: { email_template_id: id, revision_id: revision.prefixed_id }, as: :json

    expect(response).to have_http_status(:created)
    expect(json_response['draft']).to include('subject' => 'Old subject', 'body' => 'Old body')
  end

  it "does not restore another store's revision" do
    other = create(:email_template_revision, email_template: create(:email_template, store: create(:store), key: editable_key))

    post :create, params: { email_template_id: id, revision_id: other.prefixed_id }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
