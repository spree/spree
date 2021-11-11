require 'spec_helper'

describe 'Storefront API v2 CMS Pages spec', type: :request do
  let(:store) { Spree::Store.default }

  before do
    store.update(supported_locales: 'en,fr')
  end

  describe 'cms_pages#index' do
    let!(:home_en) { create(:cms_homepage, store: store) }
    let!(:standard_en) { create(:cms_standard_page, store: store, title: 'About us') }
    let!(:home_fr) { create(:cms_homepage, store: store, locale: 'fr') }
    let!(:standard_fr) { create(:cms_standard_page, store: store, locale: 'fr') }
    let!(:home_store_2) { create(:cms_homepage, store: create(:store)) }
    let(:page) { home_en }

    shared_examples 'returns proper JSON structure' do
      it 'with page attributes and relationships' do
        page.reload

        expect(json_response['data'][0]).to have_type('cms_page')
        expect(json_response['data'][0]).to have_relationships(:cms_sections)
        expect(json_response['data'][0]['id']).to eq(page.id.to_s)
        expect(json_response['data'][0]['attributes']['title']).to eq page.title
        expect(json_response['data'][0]['attributes']['locale']).to eq page.locale
        expect(json_response['data'][0]['attributes']['content']).to eq page.content
        expect(json_response['data'][0]['attributes']['meta_description']).to eq page.meta_description
        expect(json_response['data'][0]['attributes']['meta_title']).to eq page.meta_title
        expect(json_response['data'][0]['attributes']['slug']).to eq page.slug
        expect(json_response['data'][0]['attributes']['type']).to eq page.type
      end
    end

    context 'with no params' do
      before { get '/api/v2/storefront/cms_pages' }

      it_behaves_like 'returns 200 HTTP status'
      it_behaves_like 'returns proper JSON structure'

      it 'returns all pages for the current store and locale' do
        expect(json_response['data'].pluck(:id)).to contain_exactly(home_en.id.to_s, standard_en.id.to_s)
      end
    end

    context 'with locale param' do
      let(:page) { home_fr }

      before { get '/api/v2/storefront/cms_pages?locale=fr' }

      it_behaves_like 'returns 200 HTTP status'
      it_behaves_like 'returns proper JSON structure'

      it 'returns all pages for the current store and specified locale' do
        expect(json_response['data'].pluck(:id)).to contain_exactly(home_fr.id.to_s, standard_fr.id.to_s)
      end
    end

    context 'filtering by type' do
      shared_examples 'returns proper records' do
        before { get "/api/v2/storefront/cms_pages?filter[type]=#{kind}" }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns pages for the current store and specified kind' do
          expect(json_response['data'].pluck(:id)).to contain_exactly(page.id.to_s)
        end
      end

      context 'homepage' do
        let(:kind) { 'home' }
        let(:page) { home_en }

        it_behaves_like 'returns proper records'
      end

      context 'standard' do
        let(:kind) { 'standard' }
        let(:page) { standard_en }

        it_behaves_like 'returns proper records'
      end

      context 'feature' do
        let(:kind) { 'feature' }
        let!(:page) { create(:cms_feature_page, store: store) }

        it_behaves_like 'returns proper records'
      end

      context 'non-existing type' do
        before { get '/api/v2/storefront/cms_pages?filter[type]=non-existing' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns all records' do
          expect(json_response['data'].pluck(:id)).to contain_exactly(home_en.id.to_s, standard_en.id.to_s)
        end
      end
    end

    context 'filtering by title' do
      before { get '/api/v2/storefront/cms_pages?filter[title]=about' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns page with title containing the query' do
        expect(json_response['data'].pluck(:id)).to contain_exactly(standard_en.id.to_s)
      end
    end

    context 'including cms sections with linked resources' do
      let(:taxonomy) { create(:taxonomy, store: store) }
      let(:taxon) { create(:taxon, taxonomy: taxonomy) }
      let!(:cms_section) { create(:cms_hero_image_section, cms_page: home_en, linked_resource: taxon) }

      before { get '/api/v2/storefront/cms_pages?include=cms_sections.linked_resource' }

      it_behaves_like 'returns 200 HTTP status'
      it_behaves_like 'returns proper JSON structure'

      it 'returns sections and their associations' do
        page.reload

        expect(json_response['included']).to include(have_type('taxon').and(have_id(taxon.id.to_s)))
        expect(json_response['included']).to include(
          have_type('cms_section').
            and(
              have_id(cms_section.id.to_s).
              and(have_relationship(:linked_resource)).
              and(have_jsonapi_attributes(
                    :name, :content, :settings, :link, :fit, :type, :position, :is_fullscreen,
                    :img_one_sm, :img_one_md, :img_one_lg, :img_two_sm, :img_two_md, :img_two_lg,
                    :img_three_sm, :img_three_md, :img_three_lg
                  ))
            )
        )
      end
    end
  end

  describe 'cms_pages#show' do
    context 'with valid page ID' do
      let!(:page) { create(:cms_standard_page, store: store) }
      let(:taxonomy) { create(:taxonomy, store: store) }
      let(:taxon) { create(:taxon, taxonomy: taxonomy) }
      let!(:page_item) { create(:cms_hero_image_section, cms_page: page, linked_resource: taxon) }

      before { get "/api/v2/storefront/cms_pages/#{page.id}?include=cms_sections.linked_resource" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns page attributes and relationships' do
        expect(json_response['data']['id']).to eq(page.id.to_s)
        expect(json_response['data']['attributes']['title']).to eq page.title

        expect(json_response['included']).to include(have_type('taxon').and(have_id(taxon.id.to_s)))
        expect(json_response['included']).to include(have_type('cms_section').and(have_id(page_item.id.to_s).and(have_relationship(:linked_resource))))
      end
    end

    context 'with valid slug' do
      let!(:page) { create(:cms_standard_page, store: store) }

      before { get "/api/v2/storefront/cms_pages/#{page.slug}" }

      it_behaves_like 'returns 200 HTTP status'
    end

    context 'with page from different store' do
      let!(:page) { create(:cms_standard_page, store: create(:store)) }

      before { get "/api/v2/storefront/cms_pages/#{page.id}" }

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'with non-existing page ID' do
      before { get '/api/v2/storefront/cms_pages/0' }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
