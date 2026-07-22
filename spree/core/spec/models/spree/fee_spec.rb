require 'spec_helper'

describe Spree::Fee, type: :model do
  it_behaves_like 'an adjustment line'

  describe 'amount validation' do
    it 'is zero or positive — negative amounts are invalid' do
      expect(build(:fee, amount: 0)).to be_valid
      expect(build(:fee, amount: 4.99)).to be_valid
      expect(build(:fee, amount: -1)).not_to be_valid
    end
  end

  it 'requires a kind' do
    expect(build(:fee, kind: nil)).not_to be_valid
  end

  describe 'prefixed id' do
    it 'uses the fee prefix' do
      expect(create(:fee).prefixed_id).to start_with('fee_')
    end
  end
end
