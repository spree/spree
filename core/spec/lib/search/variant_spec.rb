require 'spec_helper'

describe Spree::Core::Search::Variant do
  before do
    @variant = create(:variant, sku: "ROR-0001")
    @variant_2 = create(:variant, sku: "ROR-0002")
  end

  it "can find the variant by its SKU" do
    params = {
      q: "ROR-0001"
    }

    searcher = Spree::Core::Search::Variant.new(params)
    expect(searcher.search).to include(@variant)
    expect(searcher.search).to_not include(@variant_2)
  end

  context "searching based on product name" do
    before do
      @variant.product.update_column(:name, 'Find this')
    end

    it "finds the right variant" do
      params = {
        q: 'Find this'
      }

      searcher = Spree::Core::Search::Variant.new(params)
      expect(searcher.search).to include(@variant)
      expect(searcher.search).to_not include(@variant_2)
    end
  end

  context "searching based on option value name" do
    before do
      @variant.option_values.delete_all
      @variant.option_values.create!(
        option_type: @variant.product.option_types.first,
        name: 'Find this',
        presentation: 'FIND THIS'
      )
    end

    it "finds the right variant" do
      params = {
        q: @variant.option_values.first.name
      }

      searcher = Spree::Core::Search::Variant.new(params)
      expect(searcher.search).to include(@variant)
      expect(searcher.search).to_not include(@variant_2)
    end
  end

  context "searching based on a combination" do
    before do
      @variant.product.update_column(:name, 'Big Car')
      @variant.option_values.delete_all
      @variant.option_values.create!(
        option_type: @variant.product.option_types.first,
        name: 'Red',
        presentation: 'Red'
      )
    end

    it "finds the right variant" do
      params = {
        q: 'Big Red Car'
      }

      searcher = Spree::Core::Search::Variant.new(params)
      expect(searcher.search).to include(@variant)
      expect(searcher.search).to_not include(@variant_2)
    end
  end
end
