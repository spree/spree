require 'spec_helper'

RSpec.describe Spree::Imports::CreateCategoriesJob, type: :job do
  let(:store) { @default_store }
  let!(:product) { create(:product, stores: [store]) }

  describe '#perform' do
    it 'creates taxonomies and taxons and assigns them to the product' do
      described_class.perform_now(product.id, store.id, ['Men -> Clothing -> Shirts', 'Brands -> Nike'])

      product.reload
      expect(product.taxons.map(&:pretty_name)).to contain_exactly(
        'Men -> Clothing -> Shirts',
        'Brands -> Nike'
      )

      men_taxonomy = store.taxonomies.find_by(name: 'Men')
      expect(men_taxonomy).to be_present
      expect(men_taxonomy.taxons.find_by(name: 'Clothing')).to be_present
      expect(men_taxonomy.taxons.find_by(name: 'Shirts')).to be_present

      brands_taxonomy = store.taxonomies.find_by(name: 'Brands')
      expect(brands_taxonomy).to be_present
      expect(brands_taxonomy.taxons.find_by(name: 'Nike')).to be_present
    end

    it 'reuses existing taxonomies and taxons' do
      men_taxonomy = create(:taxonomy, name: 'Men', store: store)
      clothing_taxon = create(:taxon, name: 'Clothing', taxonomy: men_taxonomy, parent: men_taxonomy.root)
      create(:taxon, name: 'Shirts', taxonomy: men_taxonomy, parent: clothing_taxon)

      expect {
        described_class.perform_now(product.id, store.id, ['Men -> Clothing -> Shirts'])
      }.not_to change { Spree::Taxon.count }

      expect(product.reload.taxons.map(&:pretty_name)).to contain_exactly(
        'Men -> Clothing -> Shirts'
      )
    end

    it 'matches taxonomies and taxons by case insensitive name' do
      men_taxonomy = create(:taxonomy, name: 'Men', store: store)
      clothing_taxon = create(:taxon, name: 'Clothing', taxonomy: men_taxonomy, parent: men_taxonomy.root)
      create(:taxon, name: 'Shirts', taxonomy: men_taxonomy, parent: clothing_taxon)

      described_class.perform_now(product.id, store.id, ['men -> clothing -> shirts'])

      expect(product.reload.taxons.map(&:pretty_name)).to contain_exactly(
        'Men -> Clothing -> Shirts'
      )
    end

    it 'skips invalid category paths' do
      described_class.perform_now(product.id, store.id, ['Men -> -> Shirts', ' -> ', '   '])

      expect(product.reload.taxons.map(&:pretty_name)).to contain_exactly('Men -> Shirts')
    end

    it 'is idempotent' do
      described_class.perform_now(product.id, store.id, ['Men -> Clothing'])
      described_class.perform_now(product.id, store.id, ['Men -> Clothing'])

      expect(product.reload.taxons.map(&:pretty_name)).to contain_exactly('Men -> Clothing')
    end

    context 'when given an empty list' do
      it 'clears existing taxons' do
        men_taxonomy = create(:taxonomy, name: 'Men', store: store)
        clothing_taxon = create(:taxon, name: 'Clothing', taxonomy: men_taxonomy, parent: men_taxonomy.root)
        product.taxons = [clothing_taxon]
        product.save!

        described_class.perform_now(product.id, store.id, [])

        expect(product.reload.taxons).to be_empty
      end
    end
  end
end
