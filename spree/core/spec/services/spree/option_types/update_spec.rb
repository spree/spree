require 'spec_helper'

RSpec.describe Spree::OptionTypes::Update do
  subject(:result) { described_class.call(option_type: option_type, params: params) }

  let!(:option_type) { create(:option_type) }
  let!(:ov1) { create(:option_value, option_type: option_type, name: 'red', presentation: 'Red', position: 1) }
  let!(:ov2) { create(:option_value, option_type: option_type, name: 'blue', presentation: 'Blue', position: 2) }

  describe 'basic update' do
    let(:params) { { presentation: 'Updated' } }

    it 'updates option type attributes' do
      expect(result).to be_success
      expect(result.value[:option_type].presentation).to eq('Updated')
    end

    it 'does not touch option values when key is absent' do
      expect(result).to be_success
      expect(option_type.option_values.count).to eq(2)
    end
  end

  describe 'validation error' do
    let(:params) { { presentation: '' } }

    it 'returns failure' do
      expect(result).not_to be_success
    end
  end

  describe 'sync option values - update existing, add new, remove missing' do
    let(:params) do
      {
        option_values: [
          { name: 'red', presentation: 'Bright Red' },
          { name: 'green', presentation: 'Green' }
        ]
      }
    end

    it 'updates red, creates green, removes blue' do
      expect(result).to be_success
      ot = result.value[:option_type]

      expect(ot.option_values.count).to eq(2)
      expect(ot.option_values.find_by(name: 'red').presentation).to eq('Bright Red')
      expect(ot.option_values.find_by(name: 'green')).to be_present
      expect(ot.option_values.find_by(name: 'blue')).to be_nil
    end
  end

  describe 'empty option_values array removes all' do
    let(:params) { { option_values: [] } }

    it 'removes all option values' do
      expect(result).to be_success
      expect(option_type.reload.option_values.count).to eq(0)
    end
  end

  describe 'option_values key absent does not sync' do
    let(:params) { { presentation: 'New Pres' } }

    it 'keeps existing option values' do
      expect(result).to be_success
      expect(option_type.reload.option_values.count).to eq(2)
    end
  end

  describe 'upsert updates position' do
    let(:params) do
      {
        option_values: [
          { name: 'red', presentation: 'Red', position: 5 },
          { name: 'blue', presentation: 'Blue', position: 10 }
        ]
      }
    end

    it 'updates positions' do
      expect(result).to be_success
      ot = result.value[:option_type]
      expect(ot.option_values.find_by(name: 'red').position).to eq(5)
      expect(ot.option_values.find_by(name: 'blue').position).to eq(10)
    end
  end

  describe 'duplicate name in same option type' do
    let(:params) do
      {
        option_values: [
          { name: 'red', presentation: 'Red' },
          { name: 'red', presentation: 'Also Red' }
        ]
      }
    end

    it 'handles duplicate gracefully via upsert (last wins)' do
      expect(result).to be_success
      ot = result.value[:option_type]
      # upsert_all with duplicate keys: only one record persists
      expect(ot.option_values.where(name: 'red').count).to eq(1)
    end
  end
end
