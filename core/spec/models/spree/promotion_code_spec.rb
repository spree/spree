require 'spec_helper'

describe Spree::PromotionCode do
  context 'callbacks' do
    subject { promotion_code.save }

    describe '#downcase_value' do
      let(:promotion) { create(:promotion, code: 'NewCoDe') }
      let(:promotion_code) { promotion.codes.first }

      it 'downcases the value before saving' do
        subject
        expect(promotion_code.value).to eq('newcode')
      end
    end
  end
end
