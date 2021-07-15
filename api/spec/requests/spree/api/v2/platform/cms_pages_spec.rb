require 'spec_helper'

describe 'Platform API v2 CmsPages', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:store) { Spree::Store.default }
  let(:page) { create(:cms_homepage, store: store) }
  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'cms_page#toggle_visibility' do
    context 'with no params' do
      let(:params) { {id: nil} }

      before do
        patch '/api/v2/platform/cms_pages/toggle_visibility', headers: bearer_token, params: params
      end

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'with correct params' do
      before do
        patch "/api/v2/platform/cms_pages/#{page.id}/toggle_visibility", headers: bearer_token
      end

      it_behaves_like 'returns 204 HTTP status'

      it 'sets page.visible from true to false' do
        page.reload
        expect(page.visible).to be false
      end
    end
  end
end
