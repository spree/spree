require 'spec_helper'

describe 'Platform API v2 CmsSections', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let(:store) { Spree::Store.default }
  let(:page) { create(:cms_homepage, store: store) }
  let(:section_a) { create(:cms_section, cms_page: page) }
  let(:section_b) { create(:cms_section, cms_page: page) }
  let(:section_c) { create(:cms_section, cms_page: page) }
  let(:section_d) { create(:cms_section, cms_page: page) }
  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'cms_section#reposition' do
    context 'with no params' do
      let(:params) { }

      before do
        patch "/api/v2/platform/cms_sections/#{section_a.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 422 HTTP status'
    end

    context 'with correct params' do
      let(:params) { { new_position_idx: 0 } }

      before do
        patch "/api/v2/platform/cms_sections/#{section_d.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'repositions section from position 4 to position 1' do
        # acts_as_list is not zero indexed so moving to
        # position 0 results in a saved postiton at 1.
        section_d.reload
        expect(section_d.position).to eq(1)
      end
    end

    context 'with correct params' do
      let(:params) { { new_position_idx: 3 } }

      before do
        patch "/api/v2/platform/cms_sections/#{section_a.id}/reposition", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'moves item from position 1 to position 4' do
        # acts_as_list is not zero indexed so moving to
        # position 3 results in a saved postiton at 4.
        section_a.reload
        expect(section_a.position).to eq(4)
      end
    end
  end
end
