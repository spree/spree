require 'spec_helper'

describe Spree::VariantPresenter do
  describe '#call' do
    subject { described_class.new(variants) }
    let :variants do
      [
        create(:variant),
        create(:variant)
      ]
    end

    it 'returns an array of variant with option_values and option_type' do
      array = subject.call

      expect(array).to_not be_empty
      array.each do |variant|
        expect(variant[:option_values]).to_not be_empty
        variant[:option_values].each do |option_value|
          expect(option_value[:option_type]).to_not be_nil
        end
      end
    end

    it 'generates request body without raising any errors' do
      expect { subject.call }.not_to raise_error
    end
  end
end
