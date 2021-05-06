require 'spec_helper'

describe Spree::ProductProperty, type: :model do
  context 'touching' do
    it 'updates product' do
      pp = create(:product_property)
      expect(pp.product).to receive(:touch)
      pp.touch
    end
  end

  context 'property_name=' do
    before do
      @pp = create(:product_property)
    end

    it 'assigns property' do
      @pp.property_name = 'Size'
      expect(@pp.property.name).to eq('Size')
    end
  end

  context 'ransackable_associations' do
    it { expect(described_class.whitelisted_ransackable_associations).to include('property') }
  end

  context 'setting param' do
    subject { build(:product_property, value: '90% Cotton 10% Elastan') }

    it { expect { subject.save! }.to change(subject, :filter_param).from(nil).to('90-cotton-10-elastan') }
  end

  context 'setting value' do
    subject { build(:product_property, value: ' 90% Cotton 10% Elastan ') }

    it { expect { subject.save! }.to change(subject, :value).to('90% Cotton 10% Elastan') }
  end
end
