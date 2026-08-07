require 'spec_helper'

RSpec.describe Spree::Imports::CreateCategoriesJob, type: :job do
  let(:store) { @default_store }
  let!(:product) { create(:product) }

  describe '#perform' do
    it 'creates categories and assigns them to the product' do
      described_class.perform_now(product.id, store.id, ['Men -> Clothing -> Shirts', 'Brands -> Nike'])

      product.reload
      expect(product.categories.map(&:pretty_name)).to contain_exactly(
        'Men -> Clothing -> Shirts',
        'Brands -> Nike'
      )

      men = store.categories.find_by(name: 'Men')
      expect(men).to be_present
      expect(men.parent).to be_nil
      expect(store.categories.find_by(name: 'Clothing').parent).to eq(men)
      expect(store.categories.find_by(name: 'Shirts').parent).to eq(store.categories.find_by(name: 'Clothing'))

      brands = store.categories.find_by(name: 'Brands')
      expect(brands).to be_present
      expect(store.categories.find_by(name: 'Nike').parent).to eq(brands)
    end

    it 'does not create taxonomies' do
      expect {
        described_class.perform_now(product.id, store.id, ['Men -> Clothing -> Shirts'])
      }.not_to change { Spree::Taxonomy.count }
    end

    it 'skips invalid category paths' do
      described_class.perform_now(product.id, store.id, ['Men -> -> Shirts', ' -> ', '   '])

      expect(product.reload.categories.map(&:pretty_name)).to contain_exactly('Men -> Shirts')
    end

    it 'is idempotent' do
      described_class.perform_now(product.id, store.id, ['Men -> Clothing'])
      described_class.perform_now(product.id, store.id, ['Men -> Clothing'])

      expect(product.reload.categories.map(&:pretty_name)).to contain_exactly('Men -> Clothing')
    end

    context "when the store's default locale differs from I18n.default_locale" do
      before { store.update_columns(default_locale: 'de') }

      it 'populates the NOT NULL base name columns instead of leaving them null' do
        # Mimics the enqueue-time locale a non-en store's request captures into the job.
        I18n.with_locale(:de) do
          described_class.perform_now(product.id, store.id, ['Men -> Clothing'])
        end

        category = product.reload.categories.first
        expect(category).to be_present
        # The raw NOT NULL base columns (not the translation) must be populated.
        expect(category.read_attribute(:name)).to eq('Clothing')
        expect(category.parent.read_attribute(:name)).to eq('Men')
      end

      it "keeps Spree::Category's Mobility.with_locale(nil) permalink regeneration working" do
        I18n.with_locale(:de) do
          described_class.perform_now(product.id, store.id, ['Men -> Clothing'])
        end

        category = product.reload.categories.first
        expect(category.read_attribute(:permalink)).to eq('men/clothing')
        expect(category.read_attribute(:pretty_name)).to eq('Men -> Clothing')
      end
    end

    context 'when categories already exist' do
      let!(:men_category) { create(:category, name: 'Men', store: store, parent: nil) }
      let!(:clothing_category) { create(:category, name: 'Clothing', store: store, parent: men_category) }
      let!(:shirts_category) { create(:category, name: 'Shirts', store: store, parent: clothing_category) }

      it 'reuses existing categories' do
        expect {
          described_class.perform_now(product.id, store.id, ['Men -> Clothing -> Shirts'])
        }.not_to change { Spree::Category.count }

        expect(product.reload.categories.map(&:pretty_name)).to contain_exactly(
          'Men -> Clothing -> Shirts'
        )
      end

      it 'matches categories by case insensitive name' do
        described_class.perform_now(product.id, store.id, ['men -> clothing -> shirts'])

        expect(product.reload.categories.map(&:pretty_name)).to contain_exactly(
          'Men -> Clothing -> Shirts'
        )
      end

      context 'when given an empty list' do
        before do
          product.categories = [shirts_category]
          product.save!
        end

        it 'clears existing categories' do
          expect {
            described_class.perform_now(product.id, store.id, [])
          }.to change { product.reload.categories.count }.from(1).to(0)
        end
      end
    end

    # An installation that has not run the upgrade task still has categories with
    # a NULL store_id resolving their store through a taxonomy. The import has to
    # find those, or it builds a parallel tree beside the merchant's own.
    it 'reuses a legacy pre-backfill category instead of creating a duplicate' do
      taxonomy = create(:taxonomy, name: 'Men', store: store)
      legacy = create(:category, name: 'Clothing', taxonomy: taxonomy, store: store)
      Spree::Category.unscoped.where(id: legacy.id).update_all(store_id: nil)

      expect {
        described_class.perform_now(product.id, store.id, ['Clothing'])
      }.not_to change { Spree::Category.unscoped.count }

      expect(product.reload.categories).to eq([legacy])
    end
  end
end
