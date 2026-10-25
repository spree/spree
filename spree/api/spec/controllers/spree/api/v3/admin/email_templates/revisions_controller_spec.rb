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

  context 'as a staffer without the email templates permission' do
    let(:staffer) do
      create(:admin_user, :without_admin_role).tap do |user|
        create(:role_user, user: user, role: create(:role, name: 'orders_only', permissions: %w[write_orders]))
      end
    end
    let(:headers) do
      { 'Authorization' => "Bearer #{Spree::Api::V3::TestingSupport.generate_jwt(staffer, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_ADMIN)}" }
    end

    it 'cannot read the history' do
      create(:email_template_revision, email_template: template)

      get :index, params: { email_template_id: id }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
