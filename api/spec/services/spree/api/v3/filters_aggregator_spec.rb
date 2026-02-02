require 'spec_helper'

RSpec.describe Spree::Api::V3::FiltersAggregator do
  let(:store) { @default_store }
  let(:currency) { 'USD' }
  let(:taxonomy) { create(:taxonomy, store: store) }
  let(:taxon) { create(:taxon, taxonomy: taxonomy) }
  let(:child_taxon) { create(:taxon, taxonomy: taxonomy, parent: taxon, name: 'Child') }

  let(:option_type) { create(:option_type, name: 'size', presentation: 'Size', filterable: true) }
  let(:option_value_s) { create(:option_value, option_type: option_type, name: 'small', presentation: 'S') }
  let(:option_value_m) { create(:option_value, option_type: option_type, name: 'medium', presentation: 'M') }

  let!(:product1) do
    create(:product, stores: [store], status: 'active', taxons: [child_taxon]).tap do |p|
      p.option_types << option_type
      create(:variant, product: p, option_values: [option_value_s])
    end
  end

  let!(:product2) do
    create(:product, stores: [store], status: 'active', taxons: [child_taxon]).tap do |p|
      p.option_types << option_type
      create(:variant, product: p, option_values: [option_value_m])
    end
  end

  let(:scope) { store.products.available(Time.current, currency) }

  subject { described_class.new(scope: scope, currency: currency, taxon: taxon) }

  describe '#call' do
    let(:result) { subject.call }

    it 'returns filters array' do
      expect(result[:filters]).to be_an(Array)
    end

    it 'returns sort_options array' do
      expect(result[:sort_options]).to be_an(Array)
      expect(result[:sort_options].first).to include(id: 'manual', label: 'Default')
    end

    it 'returns default_sort from taxon' do
      taxon.update!(sort_order: 'newest-first')
      expect(result[:default_sort]).to eq('newest-first')
    end

    it 'returns manual as default_sort when no taxon' do
      aggregator = described_class.new(scope: scope, currency: currency, taxon: nil)
      expect(aggregator.call[:default_sort]).to eq('manual')
    end

    it 'returns total_count' do
      expect(result[:total_count]).to eq(2)
    end

    describe 'price filter' do
      it 'includes price range' do
        price_filter = result[:filters].find { |f| f[:type] == 'price_range' }

        expect(price_filter).to be_present
        expect(price_filter[:min]).to be_a(Numeric)
        expect(price_filter[:max]).to be_a(Numeric)
        expect(price_filter[:currency]).to eq(currency)
      end
    end

    describe 'availability filter' do
      it 'includes in_stock and out_of_stock options' do
        availability_filter = result[:filters].find { |f| f[:type] == 'availability' }

        expect(availability_filter).to be_present
        expect(availability_filter[:options].map { |o| o[:id] }).to contain_exactly('in_stock', 'out_of_stock')
      end
    end

    describe 'option type filters' do
      it 'includes filterable option types with values' do
        size_filter = result[:filters].find { |f| f[:name] == 'size' }

        expect(size_filter).to be_present
        expect(size_filter[:type]).to eq('option')
        expect(size_filter[:label]).to eq('Size')
      end

      it 'includes option values with counts' do
        size_filter = result[:filters].find { |f| f[:name] == 'size' }
        options = size_filter[:options]

        expect(options.map { |o| o[:label] }).to contain_exactly('S', 'M')

        s_option = options.find { |o| o[:label] == 'S' }
        expect(s_option[:count]).to eq(1)
      end

      it 'excludes option types with no values in scope' do
        empty_option_type = create(:option_type, name: 'material', presentation: 'Material', filterable: true)
        create(:option_value, option_type: empty_option_type, name: 'cotton')

        material_filter = result[:filters].find { |f| f[:name] == 'material' }
        expect(material_filter).to be_nil
      end
    end

    describe 'taxon filter' do
      it 'includes child taxons when taxon is provided' do
        taxon_filter = result[:filters].find { |f| f[:type] == 'taxon' }

        expect(taxon_filter).to be_present
        expect(taxon_filter[:options].map { |t| t[:label] }).to include('Child')
      end

      it 'does not include taxon filter when no taxon provided' do
        aggregator = described_class.new(scope: scope, currency: currency, taxon: nil)
        taxon_filter = aggregator.call[:filters].find { |f| f[:type] == 'taxon' }

        expect(taxon_filter).to be_nil
      end

      it 'includes product count per taxon' do
        taxon_filter = result[:filters].find { |f| f[:type] == 'taxon' }
        child_option = taxon_filter[:options].find { |t| t[:label] == 'Child' }

        expect(child_option[:count]).to eq(2)
      end
    end
  end
end
