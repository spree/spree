require 'spec_helper'

RSpec.describe Spree::Seeds::TaxCategories do
  subject { described_class.call }

  describe 'TaxCategory' do
    let(:expected_categories) do
      [
        { name: 'Default', is_default: true },
        { name: 'Non-taxable', is_default: false }
      ]
    end

    it 'creates all TaxCategories for the store' do
      expect { subject }.to change(Spree::TaxCategory, :count).by(expected_categories.count)

      expected_categories.each do |category_attrs|
        tax_category = @default_store.tax_categories.find_by(name: category_attrs[:name])
        expect(tax_category).to be_present
        expect(tax_category.is_default).to eq(category_attrs[:is_default])
      end
    end

    it 'gives every store its own categories' do
      other_store = create(:store)

      subject

      expect(other_store.tax_categories.pluck(:name)).to match_array(expected_categories.pluck(:name))
      expect(other_store.tax_categories.find_by(is_default: true).name).to eq('Default')
      expect(@default_store.tax_categories.find_by(is_default: true).name).to eq('Default')
    end

    context 'when TaxCategories already exist' do
      before do
        expected_categories.each do |category_attrs|
          create(:tax_category, store: @default_store, name: category_attrs[:name],
                                is_default: category_attrs[:is_default])
        end
      end

      it "doesn't create new TaxCategories" do
        expect { subject }.not_to change(Spree::TaxCategory, :count)
      end

      # find_or_create_by! runs its block only on create, so seeding a store that
      # already had a Default category left it without a default — and the
      # default is what taxes an item carrying no category of its own.
      it 'marks an existing Default category as the default' do
        Spree::TaxCategory.where(store: @default_store, name: 'Default').
          update_all(is_default: false)

        subject

        expect(Spree::TaxCategory.default(@default_store)&.name).to eq('Default')
      end
    end
  end
end
