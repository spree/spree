require 'spec_helper'

describe 'Storefront API v2 Menus spec', type: :request do
  let(:store) { Spree::Store.default }

  before do
    store.update(supported_locales: 'en,fr')
  end

  describe 'menus#index' do
    let!(:header_en) { create(:menu, store: store, location: 'Header') }
    let!(:footer_en) { create(:menu, store: store, location: 'Footer') }
    let!(:header_fr) { create(:menu, store: store, location: 'Header', locale: 'fr') }
    let!(:footer_fr) { create(:menu, store: store, location: 'Footer', locale: 'fr') }
    let!(:header_store_2) { create(:menu, store: create(:store), location: 'Header') }
    let(:menu) { header_en }

    shared_examples 'returns proper JSON structure' do
      it 'with menu attributes and relationships' do
        expect(json_response['data'][0]).to have_type('menu')
        expect(json_response['data'][0]).to have_relationships(:menu_items)
        expect(json_response['data'][0]['id']).to eq(menu.id.to_s)
        expect(json_response['data'][0]['attributes']['name']).to eq menu.name
        expect(json_response['data'][0]['attributes']['location']).to eq menu.location
        expect(json_response['data'][0]['attributes']['locale']).to eq menu.locale
      end
    end

    context 'with no params' do
      before { get '/api/v2/storefront/menus' }

      it_behaves_like 'returns 200 HTTP status'
      it_behaves_like 'returns proper JSON structure'

      it 'returns all menus for the current store and locale' do
        expect(json_response['data'].pluck(:id)).to contain_exactly(header_en.id.to_s, footer_en.id.to_s)
      end
    end

    context 'with locale param' do
      let(:menu) { header_fr }

      before { get '/api/v2/storefront/menus?locale=fr' }

      it_behaves_like 'returns 200 HTTP status'
      it_behaves_like 'returns proper JSON structure'

      it 'returns all menus for the current store and specified locale' do
        expect(json_response['data'].pluck(:id)).to contain_exactly(header_fr.id.to_s, footer_fr.id.to_s)
      end
    end

    context 'including menu items with linked resources' do
      let(:product) { create(:product, stores: [store]) }
      let(:taxonomy) { create(:taxonomy, store: store) }
      let(:taxon) { create(:taxon, taxonomy: taxonomy) }
      let(:standard_page) { create(:cms_standard_page, store: store) }
      let(:feature_page) { create(:cms_feature_page, store: store) }
      let(:homepage) { create(:cms_homepage, store: store) }

      let!(:menu_item) { create(:menu_item, menu: header_en, linked_resource: taxon) }
      let!(:menu_item_product) { create(:menu_item, menu: header_en, linked_resource: product) }
      let!(:menu_item_standard_page) { create(:menu_item, menu: header_en, linked_resource: standard_page) }
      let!(:menu_item_feature_page) { create(:menu_item, menu: header_en, linked_resource: feature_page) }
      let!(:menu_item_homepage) { create(:menu_item, menu: header_en, linked_resource: homepage) }

      before { get '/api/v2/storefront/menus?include=menu_items.linked_resource' }

      it_behaves_like 'returns 200 HTTP status'
      it_behaves_like 'returns proper JSON structure'

      it 'returns menu items and their associations' do
        expect(json_response['included']).to include(have_type('taxon').and(have_id(taxon.id.to_s)))
        expect(json_response['included']).to include(
          have_type('menu_item').
            and(
              have_id(menu_item.id.to_s).
              and(have_relationship(:icon, :menu, :parent, :children, :linked_resource)).
              and(have_jsonapi_attributes(:name, :code, :subtitle, :link, :new_window, :lft, :rgt, :depth, :is_container, :is_root, :is_child, :is_leaf))
            )
        )
      end

      context 'filtering by location' do
        before { get '/api/v2/storefront/menus?filter[location]=header' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns menus for the current store and specified location' do
          expect(json_response['data'].pluck(:id)).to contain_exactly(header_en.id.to_s)
        end
      end
    end
  end

  describe 'menus#show' do
    context 'with valid menu ID' do
      let!(:menu) { create(:menu, store: store) }
      let(:taxonomy) { create(:taxonomy, store: store) }
      let(:taxon) { create(:taxon, taxonomy: taxonomy) }
      let!(:menu_item) { create(:menu_item, menu: menu, linked_resource: taxon) }

      before { get "/api/v2/storefront/menus/#{menu.id}?include=menu_items.linked_resource" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns menu attributes and relationships' do
        expect(json_response['data']['id']).to eq(menu.id.to_s)
        expect(json_response['data']['attributes']['name']).to eq menu.name
        expect(json_response['data']['attributes']['location']).to eq menu.location
        expect(json_response['data']['attributes']['locale']).to eq menu.locale

        expect(json_response['included']).to include(have_type('taxon').and(have_id(taxon.id.to_s)))
        expect(json_response['included']).to include(have_type('menu_item').and(have_id(menu_item.id.to_s).and(have_relationship(:icon, :menu, :parent, :children, :linked_resource))))
      end
    end

    context 'with menu from different store' do
      let!(:menu) { create(:menu, store: create(:store)) }

      before { get "/api/v2/storefront/menus/#{menu.id}" }

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'with non-existing menu ID' do
      before { get '/api/v2/storefront/menus/0' }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
