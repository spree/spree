require 'spec_helper'

module Spree
  RSpec.describe Filters::OptionsPresenter do
    let(:options) { described_class.new(option_values_scope: OptionValue.where(id: option_values)) }

    let(:size) { create(:option_type, :size) }
    let(:s_size) { create(:option_value, option_type: size, name: 's') }
    let(:m_size) { create(:option_value, option_type: size, name: 'm') }

    let(:color) { create(:option_type, :color) }
    let(:red_color) { create(:option_value, option_type: color, name: 'red') }
    let(:green_color) { create(:option_value, option_type: color, name: 'green') }
    let(:blue_color) { create(:option_value, option_type: color, name: 'blue') }

    let(:option_values) do
      [
        s_size, m_size,
        red_color, green_color, blue_color
      ]
    end

    describe '#to_a' do
      subject(:filterable_options) { options.to_a }

      it 'returns filterable Option Types and Values' do
        aggregate_failures 'filterable options' do
          size_option = filterable_options.find { |option| option.option_type == size }
          expect(size_option.option_values).to contain_exactly(s_size, m_size)

          color_option = filterable_options.find { |option| option.option_type == color }
          expect(color_option.option_values).to contain_exactly(red_color, green_color, blue_color)
        end
      end
    end
  end
end
