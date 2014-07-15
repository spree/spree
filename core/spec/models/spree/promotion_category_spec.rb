require 'spec_helper'

describe Spree::PromotionCategory do
  describe 'validation' do
    let(:name) { 'Nom' }
    subject { Spree::PromotionCategory.new name: name }

    context 'when all required attributes are specified' do
      it { should be_valid }
    end

    context 'when name is missing' do
      let(:name) { nil }
      it { should_not be_valid }
    end
  end
end
