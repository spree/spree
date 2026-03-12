require 'spec_helper'

RSpec.describe Spree::OptionTypes::Create do
  subject(:result) { described_class.call(params: params) }

  describe 'basic creation' do
    let(:params) { { name: 'color', presentation: 'Color' } }

    it 'creates an option type' do
      expect(result).to be_success
      expect(result.value[:option_type].name).to eq('color')
      expect(result.value[:option_type].presentation).to eq('Color')
    end
  end

  describe 'validation error - missing presentation' do
    let(:params) { { name: 'bad' } }

    it 'returns failure' do
      expect(result).not_to be_success
    end
  end

  describe 'validation error - blank name and presentation' do
    let(:params) { { name: '', presentation: '' } }

    it 'returns failure' do
      expect(result).not_to be_success
    end
  end

  describe 'duplicate name' do
    before { create(:option_type, name: 'size') }
    let(:params) { { name: 'size', presentation: 'Size' } }

    it 'returns failure' do
      expect(result).not_to be_success
    end
  end

  describe 'with nested option values' do
    let(:params) do
      {
        name: 'material',
        presentation: 'Material',
        option_values: [
          { name: 'cotton', presentation: 'Cotton' },
          { name: 'silk', presentation: 'Silk' },
          { name: 'wool', presentation: 'Wool' }
        ]
      }
    end

    it 'creates option values via insert_all' do
      expect(result).to be_success
      ot = result.value[:option_type]
      expect(ot.option_values.count).to eq(3)
      expect(ot.option_values.pluck(:name)).to match_array(%w[cotton silk wool])
    end

    it 'assigns positions' do
      ot = result.value[:option_type]
      positions = ot.option_values.order(:position).pluck(:position)
      expect(positions).to eq([1, 2, 3])
    end
  end

  describe 'with explicit positions' do
    let(:params) do
      {
        name: 'size',
        presentation: 'Size',
        option_values: [
          { name: 'large', presentation: 'Large', position: 3 },
          { name: 'small', presentation: 'Small', position: 1 }
        ]
      }
    end

    it 'uses provided positions' do
      expect(result).to be_success
      ot = result.value[:option_type]
      expect(ot.option_values.find_by(name: 'small').position).to eq(1)
      expect(ot.option_values.find_by(name: 'large').position).to eq(3)
    end
  end

  describe 'without option values' do
    let(:params) { { name: 'weight', presentation: 'Weight' } }

    it 'creates option type with no values' do
      expect(result).to be_success
      expect(result.value[:option_type].option_values).to be_empty
    end
  end
end
