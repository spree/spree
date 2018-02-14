require 'spec_helper'

describe Spree::RefundReason do
  describe 'Class Methods' do
    describe '.return_processing_reason' do
      context 'default refund reason present' do
        let!(:default_refund_reason) { create(:default_refund_reason) }

        it { expect(described_class.return_processing_reason).to eq(default_refund_reason) }
      end

      context 'default refund reason not present' do
        it { expect(described_class.return_processing_reason).to eq(nil) }
      end
    end
  end
end
