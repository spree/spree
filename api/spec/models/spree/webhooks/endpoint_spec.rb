require 'spec_helper'

describe Spree::Store do
  describe 'validations' do
    context 'url presence' do
      it 'is valid with url' do
        expect(build(:endpoint, url: 'https://google.com/').valid?).to be(true)
      end

      it 'is invalid without url' do
        expect(build(:endpoint, url: nil).valid?).to be(false)
      end
    end
  end
end
