require 'spec_helper'

module Spree
  RSpec.describe OptionValues::FindAvailable do
    let(:taxon) { create(:taxon) }
    let(:gbp) { 'GBP' }

    let!(:size) { create(:option_type, :size) }
    let!(:s_size) { create(:option_value, option_type: size, name: 's') }
    let!(:m_size) { create(:option_value, option_type: size, name: 'm') }
    let!(:xl_size) { create(:option_value, option_type: size, name: 'xl') }

    let!(:color) { create(:option_type, :color) }
    let!(:red_color) { create(:option_value, option_type: color, name: 'red') }
    let!(:green_color) { create(:option_value, option_type: color, name: 'green') }
    let!(:blue_color) { create(:option_value, option_type: color, name: 'blue') }

    let!(:length) { create(:option_type, filterable: false) }
    let!(:mini) { create(:option_value, option_type: length) }

    before do
      product_1 = create(:product, option_types: [color, size], taxons: [taxon], currency: gbp)
      create(:variant, option_values: [s_size, green_color], product: product_1)

      product_2 = create(:product, option_types: [color, size], taxons: [taxon], currency: gbp)
      create(:variant, option_values: [red_color, m_size], product: product_2)

      product_3 = create(:product, option_types: [size, length], taxons: [taxon], currency: gbp)
      create(:variant, option_values: [s_size, mini], product: product_3)

      product_4 = create(:product, option_types: [color], taxons: [create(:taxon)], currency: gbp)
      create(:variant, option_values: [blue_color], product: product_4)

      product_5 = create(:product, option_types: [size], taxons: [taxon], currency: 'PLN')
      create(:variant, option_values: [xl_size], product: product_5)
    end

    describe '#execute' do
      subject(:available_options) { finder.execute }

      context 'when taxon and currency are given' do
        let(:finder) { described_class.new(taxon: taxon, currency: gbp) }

        it 'finds available Option Values' do
          expect(available_options).to contain_exactly(
            s_size, m_size,
            red_color, green_color
          )
        end
      end

      context 'when no taxon is given' do
        let(:finder) { described_class.new(currency: gbp) }

        it 'finds available Option Values in all Taxons' do
          expect(available_options).to contain_exactly(
            s_size, m_size,
            red_color, green_color, blue_color
          )
        end
      end

      context 'when no currency is given' do
        let(:finder) { described_class.new(taxon: taxon) }

        it 'finds available Option Values for all Currencies' do
          expect(available_options).to contain_exactly(
            s_size, m_size, xl_size,
            red_color, green_color
          )
        end
      end
    end
  end
end
