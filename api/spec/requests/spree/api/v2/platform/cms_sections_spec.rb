require 'spec_helper'

describe 'Platform API v2 CmsSections', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let!(:store) { Spree::Store.default }
  let!(:page) { create(:cms_homepage, store: store) }
  let!(:section_a) { create(:cms_section, cms_page: page) }
  let!(:section_b) { create(:cms_section, cms_page: page) }
  let!(:section_c) { create(:cms_section, cms_page: page) }
  let!(:section_d) { create(:cms_section, cms_page: page) }
  let!(:section_e) { create(:cms_section, cms_page: page) }
  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'cms_section#update' do
    context 'move section_a from position 1 down to position 5' do
      let(:params) do
        {
          cms_section: { position: 5 }
        }
      end

      before do
        patch "/api/v2/platform/cms_sections/#{section_a.id}", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'moves section_a from position 1 to position 5 and updates the positions of the other sections accordingly' do
        reload_sections

        expect(section_b.position).to eq(1)
        expect(section_c.position).to eq(2)
        expect(section_d.position).to eq(3)
        expect(section_e.position).to eq(4)
        expect(section_a.position).to eq(5)
      end
    end

    context 'can accept 0 and move the item to position 1' do
      let(:params) do
        {
          cms_section: {
            name: 'Rename section and update Position!',
            position: 0
          }
        }
      end

      before do
        patch "/api/v2/platform/cms_sections/#{section_d.id}", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'moves section_d from position 4 to position 1 by passing position: 0, and renames the section' do
        reload_sections
        expect(section_d.position).to eq(1)
        expect(section_d.name).to eq('Rename section and update Position!')
      end
    end

    def reload_sections
      section_a.reload
      section_b.reload
      section_c.reload
      section_d.reload
      section_e.reload
    end
  end
end
