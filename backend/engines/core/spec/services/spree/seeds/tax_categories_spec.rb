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

    it 'creates all TaxCategories' do
      expect { subject }.to change(Spree::TaxCategory, :count).by(expected_categories.count)

      expected_categories.each do |category_attrs|
        tax_category = Spree::TaxCategory.find_by(name: category_attrs[:name])
        expect(tax_category).to be_present
        expect(tax_category.is_default).to eq(category_attrs[:is_default])
      end
    end

    context 'when TaxCategories already exist' do
      before do
        expected_categories.each do |category_attrs|
          Spree::TaxCategory.create!(name: category_attrs[:name], is_default: category_attrs[:is_default])
        end
      end

      it "doesn't create new TaxCategories" do
        expect { subject }.not_to change(Spree::TaxCategory, :count)
      end
    end
  end
end
