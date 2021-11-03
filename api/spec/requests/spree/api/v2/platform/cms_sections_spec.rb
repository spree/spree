require 'spec_helper'

describe 'Platform API v2 CmsSections', type: :request do
  include_context 'API v2 tokens'
  include_context 'Platform API v2'

  let!(:store) { Spree::Store.default }
  let!(:page) { create(:cms_homepage, store: store) }

  let!(:resource_a) { create(:cms_hero_image_section, cms_page: page) }
  let!(:resource_b) { create(:cms_featured_article_section, cms_page: page) }
  let!(:resource_c) { create(:cms_product_carousel_section, cms_page: page) }
  let!(:resource_d) { create(:cms_image_gallery_section, cms_page: page) }
  let!(:resource_e) { create(:cms_side_by_side_images_section, cms_page: page) }
  let!(:resource_f) { create(:cms_rich_text_content_section, cms_page: page) }

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

  describe 'cms_sections#update' do
    context 'move resource_a from position 1 down to position 5' do
      let(:params) do
        {
          cms_section: { position: 5 }
        }
      end

      before do
        patch "/api/v2/platform/cms_sections/#{resource_a.id}", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'moves resource_a from position 1 to position 5 and updates the positions of its siblings accordingly' do
        reload_sections

        expect(resource_b.position).to eq(1)
        expect(resource_c.position).to eq(2)
        expect(resource_d.position).to eq(3)
        expect(resource_e.position).to eq(4)
        expect(resource_a.position).to eq(5)
        expect(resource_f.position).to eq(6)
      end
    end

    context 'can move position and update other attribute' do
      let(:params) do
        {
          cms_section: {
            name: 'Rename resource and update Position!',
            position: 1
          }
        }
      end

      before do
        patch "/api/v2/platform/cms_sections/#{resource_d.id}", headers: bearer_token, params: params
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'moves resource_d from position 4 to position 1, and updates the name' do
        reload_sections
        expect(resource_d.position).to eq(1)
        expect(resource_d.name).to eq('Rename resource and update Position!')
      end
    end

    def reload_sections
      resource_a.reload
      resource_b.reload
      resource_c.reload
      resource_d.reload
      resource_e.reload
      resource_f.reload
    end
  end
end
