require 'spec_helper'

describe 'Taxons Spec', type: :request do
  let!(:store) { @default_store }
  let!(:taxonomy) { store.taxonomies.first }
  let!(:taxons) { create_list(:taxon, 2, taxonomy: taxonomy, parent: taxonomy.root) }

  before do
    store.update_column(:supported_locales, 'en,pl,es')
    allow(Spree::Api::Config).to receive(:[]).and_call_original
    allow(Spree::Api::Config).to receive(:[]).with(:api_v2_per_page_limit).and_return(2)
  end

  after { I18n.locale = :en }

  shared_examples 'returns valid taxon resource JSON' do
    it 'returns a valid taxon resource JSON response' do
      expect(response.status).to eq(200)

      expect(json_response['data']).to have_type('taxon')
      expect(json_response['data']).to have_relationships(:parent, :taxonomy, :children, :products, :image)
    end
  end

  describe 'taxons#index' do
    context 'with no params' do
      before { get '/api/v2/storefront/taxons' }

      it 'returns all taxons' do
        expect(json_response['data'].size).to eq(store.taxons.count)
        expect(json_response['data'][0]).to have_type('taxon')
        expect(json_response['data'][0]).to have_relationships(:parent, :taxonomy, :children, :image)
        expect(json_response['data'][0]).not_to have_relationships(:produts)
      end
    end

    context 'with locale set to pl' do
      let!(:store) do
        store = taxonomy.store
        store.supported_locales = 'en,pl'
        store.save
        store
      end

      let!(:taxonomy) do
        taxonomy_localized = create(:taxonomy)
        taxonomy_root_localized = taxonomy_localized.root

        name = taxonomy_localized.name

        Mobility.with_locale(:pl) do
          taxonomy_localized.update!(name: "Localized Taxonomy PL")
          taxonomy_root_localized.update!(name: "Localized Taxonomy PL", pretty_name: "Localized Taxonomy PL")
        end

        taxonomy_localized
      end

      let!(:taxons) do
        taxons_localized = create_list(:taxon, 2, taxonomy: taxonomy, parent: taxonomy.root)
        taxons_localized.each_with_index do |taxon, index|
          name = taxon.name
          Mobility.with_locale(:pl) { taxon.update!(name: "Localized Taxon #{index + 1} PL", pretty_name: "Localized Taxon #{index + 1} PL") }
        end

        taxons_localized
      end

      before { get '/api/v2/storefront/taxons?locale=pl' }

      # FIXME: this test fails on CI but works locally
      xit 'returns all taxons' do
        expect(json_response['data'].size).to eq(3)

        expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:name).with_value("Localized Taxonomy PL")))
        expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:pretty_name).with_value("Localized Taxonomy PL")))
        expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:permalink).with_value('localized-taxonomy-pl')))

        expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:name).with_value("Localized Taxon 1 PL")))
        expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:pretty_name).with_value("Localized Taxonomy PL -> Localized Taxon 1 PL")))
        expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:permalink).with_value('localized-taxonomy-pl/localized-taxon-1-pl')))

        expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:name).with_value("Localized Taxon 2 PL")))
        expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:pretty_name).with_value("Localized Taxonomy PL -> Localized Taxon 2 PL")))
        expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:permalink).with_value('localized-taxonomy-pl/localized-taxon-2-pl')))
      end
    end

    context 'by roots' do
      before { get '/api/v2/storefront/taxons?filter[roots]=true' }

      it 'returns taxons by roots' do
        expect(json_response['data'].size).to eq(store.taxons.where(parent: nil).count)
        expect(json_response['data'][0]).to have_type('taxon')
        expect(json_response['data'][0]).to have_id(store.taxonomies.first.root.id.to_s)
        expect(json_response['data'][0]).to have_relationship(:parent).with_data(nil)
        expect(json_response['data'][0]).to have_relationships(:parent, :taxonomy, :children, :image)
      end
    end

    context 'by parent' do
      before { get "/api/v2/storefront/taxons?filter[parent_id]=#{taxonomy.root.id}" }

      it 'returns children taxons by parent' do
        expect(json_response['data'].size).to eq(2)
        expect(json_response['data'][0]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')
        expect(json_response['data'][1]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')
      end
    end

    context 'by parent permalink' do
      let!(:taxonomy_3) { create(:taxonomy, store: taxonomy.store) }
      let!(:taxon_3) { create(:taxon, taxonomy: taxonomy_3, parent: taxonomy_3.root) }

      let(:request_path) { "/api/v2/storefront/taxons?filter[parent_permalink]=#{taxonomy.root.permalink}" }

      before do
        taxonomy_root_name = taxonomy.root.name
        taxon_1_name = taxons[0].name
        taxon_2_name = taxons[1].name

        Mobility.with_locale(:pl) do
          taxonomy.root.update!(name: "#{taxonomy_root_name}_pl")
          taxons[0].update!(name: "#{taxon_1_name}_pl")
          taxons[1].update!(name: "#{taxon_2_name}_pl")
        end

        get request_path
      end

      it 'returns children taxons by parent' do
        expect(json_response['data'].size).to eq(2)
        expect(json_response['data'][0]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')
        expect(json_response['data'][1]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')
      end

      context 'with another locale' do
        let(:request_path) { "/api/v2/storefront/taxons?filter[parent_permalink]=#{taxonomy.root.permalink_pl}&locale=pl" }

        it 'returns children taxons by parent' do
          expect(json_response['data'].size).to eq(2)

          expect(json_response['data'][0]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')
          expect(json_response['data'][1]).to have_relationship(:parent).with_data('id' => taxonomy.root.id.to_s, 'type' => 'taxon')

          expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:name).with_value(taxons[0].name_pl)))
          expect(json_response['data']).to include(have_type('taxon').and(have_attribute(:name).with_value(taxons[1].name_pl)))
        end
      end
    end

    context 'by taxonomy' do
      before { get "/api/v2/storefront/taxons?filter[taxonomy_id]=#{taxonomy.id}" }

      it 'returns taxons by taxonomy' do
        expect(json_response['data'].size).to eq(taxonomy.taxons.count)
        expect(json_response['data'][0]).to have_relationship(:taxonomy).with_data('id' => taxonomy.id.to_s, 'type' => 'taxonomy')
        expect(json_response['data'][1]).to have_relationship(:taxonomy).with_data('id' => taxonomy.id.to_s, 'type' => 'taxonomy')
        expect(json_response['data'][2]).to have_relationship(:taxonomy).with_data('id' => taxonomy.id.to_s, 'type' => 'taxonomy')
      end
    end

    context 'by ids' do
      before { get "/api/v2/storefront/taxons?filter[ids]=#{taxons.map(&:id).join(',')}" }

      it 'returns taxons by ids' do
        expect(json_response['data'].size).to            eq(2)
        expect(json_response['data'].pluck(:id).sort).to eq(taxons.map(&:id).map(&:to_s).sort)
      end
    end

    context 'by name' do
      before { get "/api/v2/storefront/taxons?filter[name]=#{taxons.last.name}" }

      it 'returns taxons by name' do
        expect(json_response['data'].size).to eq(1)
        expect(json_response['data'].last['attributes']['name']).to eq(taxons.last.name)
      end
    end
  end

  describe 'taxons#show' do
    let(:taxon) { taxons.first }

    context 'by id' do
      before do
        get "/api/v2/storefront/taxons/#{taxon.id}"
      end

      it_behaves_like 'returns valid taxon resource JSON'

      it 'returns taxon by id' do
        expect(json_response['data']).to have_id(taxon.id.to_s)
        expect(json_response['data']).to have_attribute(:name).with_value(taxon.name)
      end
    end

    context 'by permalink' do
      before do
        get "/api/v2/storefront/taxons/#{store.taxons.first.permalink}"
      end

      it_behaves_like 'returns valid taxon resource JSON'

      it 'returns taxon by permalink' do
        expect(json_response['data']).to have_id(store.taxons.first.id.to_s)
        expect(json_response['data']).to have_attribute(:name).with_value(store.taxons.first.name)
      end
    end

    context 'with localized_slugs' do
      let(:store2) { create(:store, default_locale: 'en', supported_locales: 'en,pl,es') }
      let(:taxonomy) { store2.taxonomies.find_by(name: 'Categories') }
      let!(:taxon_with_slug) { create(:taxon, taxonomy: taxonomy, permalink: 'test_slug_en') }
      let!(:translations) { taxon_with_slug.translations.create([{ permalink: 'test_slug_pl', locale: 'pl' }, { permalink: 'test_slug_es', locale: 'es' } ])}

      let(:expected_slugs) do
        {
          en: 'categories/test-slug-en',
          pl: 'categories/test-slug-pl',
          es: 'categories/test-slug-es'
        }
      end

      before do
        allow_any_instance_of(Spree::Api::V2::Storefront::TaxonsController).to receive(:current_store).and_return(store2)
        get "/api/v2/storefront/taxons/#{taxon_with_slug.id}"
      end

      it 'returns translated slugs' do
        expect(json_response['data']['attributes']['localized_slugs']).to match(expected_slugs)
      end
    end

    context 'with fallback to default locale' do
      let(:store2) { create(:store, default_locale: 'en', supported_locales: 'en,pl,es') }
      let(:taxonomy) { store2.taxonomies.find_by(name: 'Categories') }
      let!(:taxon_with_slug) { create(:taxon, taxonomy: taxonomy, name: 'test slug en', permalink: default_locale_slug) }
      let(:default_locale_slug) { 'test-slug-en' }

      before do
        allow_any_instance_of(Spree::Api::V2::Storefront::TaxonsController).to receive(:current_store).and_return(store2)
        get "/api/v2/storefront/taxons/categories/#{default_locale_slug}?locale=es"
      end

      it 'finds the taxon' do
        expect(json_response['data']['id']).to eq(taxon_with_slug.id.to_s)
      end
    end

    context 'with slug in translated locale' do
      let(:store2) { create(:store, default_locale: 'en', supported_locales: 'en,pl,es') }
      let(:taxonomy) { store2.taxonomies.find_by(name: 'Categories') }
      let!(:taxon_with_slug) { create(:taxon, taxonomy: taxonomy, permalink: default_locale_slug) }
      let!(:translations) { taxon_with_slug.translations.create([ { name: 'test slug en', permalink: translated_slug, locale: 'es' } ]) }
      let(:default_locale_slug) { 'test_slug_en' }
      let(:translated_slug) { 'test-slug-es' }

      before do
        allow_any_instance_of(Spree::Api::V2::Storefront::TaxonsController).to receive(:current_store).and_return(store2)
        get "/api/v2/storefront/taxons/categories/#{translated_slug}?locale=es"
      end

      it 'finds the taxon' do
        expect(json_response['data']['id']).to eq(taxon_with_slug.id.to_s)
      end
    end

    context 'with taxon image data' do
      shared_examples 'returns taxon image data' do
        it 'returns taxon image data' do
          expect(json_response['included'].count).to eq(1)
          expect(json_response['included'].first['type']).to eq('taxon_image')
        end
      end

      let!(:image) { create(:taxon_image, viewable: taxon) }
      let(:image_json_data) { json_response['included'].first['attributes'] }

      before { get "/api/v2/storefront/taxons/#{taxon.id}?include=image#{taxon_image_transformation_params}" }

      context 'when no image transformation params are passed' do
        let(:taxon_image_transformation_params) { '' }

        it_behaves_like 'returns taxon image data'

        it 'returns taxon image' do
          expect(image_json_data['transformed_url']).to be_nil
        end
      end

      context 'when taxon image json returned' do
        let(:taxon_image_transformation_params) { '&taxon_image_transformation[size]=100x50&taxon_image_transformation[quality]=50' }

        it_behaves_like 'returns taxon image data'

        it 'returns taxon image' do
          expect(image_json_data['transformed_url']).not_to be_nil
        end
      end
    end
  end
end
