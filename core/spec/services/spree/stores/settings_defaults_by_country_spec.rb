require 'spec_helper'

RSpec.describe Spree::Stores::SettingsDefaultsByCountry do
  subject { described_class.call(code: code) }

  context 'when country code is US' do
    let(:code) { 'US' }

    it 'returns imperial unit system' do
      expect(subject.value).to eq(timezone: "Central Time (US & Canada)", unit_system: :imperial, weight_unit: 'lb')
    end
  end

  context 'when country code is not US' do
    let(:code) { 'PL' }

    it 'returns metric unit system' do
      expect(subject.value).to eq(timezone: 'Warsaw', unit_system: :metric, weight_unit: 'kg')
    end
  end
end
