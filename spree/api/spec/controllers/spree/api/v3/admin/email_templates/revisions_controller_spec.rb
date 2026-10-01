require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::EmailTemplates::RevisionsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'
  include_context 'with an editable email template'

  let(:id) { editable_key.tr('/', '.') }
  let(:template) { create(:email_template, store: store, key: editable_key) }

  before { request.headers.merge!(headers) }

  it "lists the template's published versions in one language, newest first" do
    older = create(:email_template_revision, email_template: template, created_at: 2.days.ago, published_by: admin_user)
    newer = create(:email_template_revision, email_template: template, created_at: 1.day.ago)
    create(:email_template_revision, email_template: create(:email_template, store: store, key: editable_key, locale: 'de'))
    create(:email_template_revision, email_template: create(:email_template, store: create(:store), key: editable_key))

    get :index, params: { email_template_id: id }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['data'].map { |revision| revision['id'] }).to eq([newer.prefixed_id, older.prefixed_id])
    expect(json_response['data'].last['published_by_type']).to eq('admin_user')
  end
end
