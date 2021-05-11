require 'spec_helper'

module Spree
  RSpec.describe OptionValues::FindFilterable do
    let(:finder) { described_class.new }

    describe '#execute' do
      let(:filterable_option_values) { finder.execute }

      let!(:size) { create(:option_type, :size) }
      let!(:s_size) { create(:option_value, option_type: size, name: 's') }
      let!(:m_size) { create(:option_value, option_type: size, name: 'm') }
      let!(:xl_size) { create(:option_value, option_type: size, name: 'xl') }

      let!(:color) { create(:option_type, :color) }
      let!(:red_color) { create(:option_value, option_type: color, name: 'red') }
      let!(:green_color) { create(:option_value, option_type: color, name: 'green') }
      let!(:blue_color) { create(:option_value, option_type: color, name: 'blue') }
      let!(:purple_color) { create(:option_value, option_type: color, name: 'purple') }

      let!(:non_filterable_option) { create(:option_type, filterable: false) }
      let!(:non_filterable_value) { create(:option_value, option_type: non_filterable_option) }

      before do
        create(
          :variant,
          option_values: [m_size, red_color],
          product: create(:product, option_types: [color, size])
        )

        create(
          :variant,
          option_values: [s_size, green_color, blue_color],
          product: create(:product, option_types: [color, size])
        )

        create(
          :variant,
          option_values: [s_size, green_color],
          product: create(:product, option_types: [color])
        )

        create(
          :variant,
          option_values: [non_filterable_value],
          product: create(:product, option_types: [non_filterable_option])
        )
      end

      it 'finds filterable Option Values' do
        expect(filterable_option_values).to contain_exactly(
          s_size, m_size,
          red_color, green_color, blue_color
        )
      end

      context 'when given a predefined scope' do
        let(:finder) { described_class.new(scope: scope) }
        let(:scope) { OptionValue.where(id: [s_size, green_color, purple_color, non_filterable_value]) }

        it 'finds filterable Option Values with respect to a predefined scope' do
          expect(filterable_option_values).to contain_exactly(s_size, green_color)
        end
      end

      context 'when given a predefined products scope' do
        let(:finder) { described_class.new(products_scope: products_scope) }
        let(:products_scope) { Product.where(id: [product_1, product_2, product_3]) }

        let(:product_1) { create(:product, option_types: [size]) }
        let(:product_2) { create(:product, option_types: [color]) }
        let(:product_3) { create(:product, option_types: [size, color, non_filterable_option]) }

        before do
          create(:variant, option_values: [xl_size], product: product_1)
          create(:variant, option_values: [red_color, purple_color], product: product_2)
          create(:variant, option_values: [m_size, green_color, non_filterable_value], product: product_3)
        end

        it 'finds filterable Option Values with respect to a predefined Products scope' do
          expect(filterable_option_values).to contain_exactly(
            m_size, xl_size,
            red_color, green_color, purple_color,
          )
        end
      end
    end
  end
end
