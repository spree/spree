require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::EmailTemplates::SampleRecordsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'
  include_context 'with an editable email template'

  let(:id) { editable_key.tr('/', '.') }

  before { request.headers.merge!(headers) }

  it "lists the store's latest records to preview with, newest first" do
    orders = create_list(:order, 6, store: store)
    create(:order, store: create(:store))

    get :index, params: { email_template_id: id }, as: :json

    expect(response).to have_http_status(:ok)
    expect(json_response['data'].map { |record| record['id'] }).to eq(orders.sort_by(&:created_at).reverse.first(5).map(&:prefixed_id))
    expect(json_response['data'].first).to include('label', 'created_at')
  end

  context 'without permission to read the records' do
    let(:headers) { { 'x-spree-api-key' => create(:api_key, :secret, store: store, scopes: %w[write_email_templates]).plaintext_token } }

    before { allow(Spree::TestingSupport::EmailTemplateSample).to receive(:required_permissions).and_return(%w[read_orders]) }

    it 'is refused' do
      get :index, params: { email_template_id: id }, as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
