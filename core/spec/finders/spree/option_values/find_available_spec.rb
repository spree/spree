require 'spec_helper'

module Spree
  RSpec.describe OptionValues::FindAvailable do
    let(:finder) { described_class.new }

    let!(:size) { create(:option_type, :size) }
    let!(:s_size) { create(:option_value, option_type: size, name: 's') }
    let!(:m_size) { create(:option_value, option_type: size, name: 'm') }
    let!(:xl_size) { create(:option_value, option_type: size, name: 'xl') }

    let!(:color) { create(:option_type, :color) }
    let!(:red_color) { create(:option_value, option_type: color, name: 'red') }
    let!(:green_color) { create(:option_value, option_type: color, name: 'green') }
    let!(:blue_color) { create(:option_value, option_type: color, name: 'blue') }

    let!(:length) { create(:option_type, filterable: false) }
    let!(:mini_length) { create(:option_value, option_type: length) }

    before do
      product_1 = create(:product, option_types: [color, size])
      create(:variant, option_values: [s_size, green_color], product: product_1)

      product_2 = create(:product, option_types: [color, size])
      create(:variant, option_values: [red_color, m_size], product: product_2)

      product_3 = create(:product, option_types: [size, length])
      create(:variant, option_values: [s_size, mini_length], product: product_3)
    end

    describe '#execute' do
      subject(:available_options) { finder.execute }

      it 'finds available Option Values' do
        expect(available_options).to contain_exactly(
          s_size, m_size,
          red_color, green_color
        )
      end

      context 'when given a predefined scope' do
        let(:finder) { described_class.new(scope: scope) }
        let(:scope) { OptionValue.where(id: [s_size, green_color, mini_length]) }

        it 'finds available Option Values with respect to a predefined scope' do
          expect(available_options).to contain_exactly(s_size, green_color)
        end
      end

      context 'when given a predefined products scope' do
        let(:finder) { described_class.new(products_scope: products_scope) }
        let(:products_scope) { Product.where(id: [product_1, product_2, product_3]) }

        let(:product_1) { create(:product, option_types: [size]) }
        let(:product_2) { create(:product, option_types: [color]) }
        let(:product_3) { create(:product, option_types: [size, color, length]) }

        before do
          create(:variant, option_values: [xl_size], product: product_1)
          create(:variant, option_values: [red_color, blue_color], product: product_2)
          create(:variant, option_values: [m_size, red_color, mini_length], product: product_3)
        end

        it 'finds filterable Option Values with respect to a predefined Products scope' do
          expect(available_options).to contain_exactly(
            m_size, xl_size,
            red_color, blue_color
          )
        end
      end

      context 'ordering' do
        let!(:white_color) { create(:option_value, option_type: color, name: 'white') }
        let!(:black_color) { create(:option_value, option_type: color, name: 'black') }
        let!(:material) { create(:option_type, name: 'material', presentation: 'Material') }
        let!(:wool) { create(:option_value, option_type: material, name: 'wool') }
        let!(:silk) { create(:option_value, option_type: material, name: 'silk') }

        before do
          material.update_column(:position, 0)
          silk.update_column(:position, 1)
          wool.update_column(:position, 2)

          color.update_column(:position, 1)
          white_color.update_column(:position, 0)
          black_color.update_column(:position, 10)
          green_color.update_column(:position, 20)

          size.update_column(:position, 2)

          product_4 = create(:product, option_types: [color, material, size])
          create(:variant, option_values: [white_color, black_color, wool, silk], product: product_4)
        end

        it 'orders the option values by option type position and option value position' do
          positions = available_options.map { |ov| [ov.option_type.position, ov.position] }
          expect(positions).to eq(positions.sort_by { |e| [e.first, e.second] })
        end
      end
    end
  end
end
