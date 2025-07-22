require 'spec_helper'

module Spree
  module CouponCodes
    describe BulkGenerateJob, type: :job do
      let!(:promotion) { create(:promotion, multi_codes: true, kind: :coupon_code, number_of_codes: 1000) }
      let(:quantity) { 1000 }

      describe '#perform' do
        subject(:perform_job) { described_class.perform_now(promotion.id, quantity) }

        it 'generates coupon codes' do
          expect { subject }.to change(Spree::CouponCode, :count).by(1000)
        end
      end
    end
  end
end
