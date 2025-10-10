require 'spec_helper'

describe Spree::RefundReason do
  describe 'Class Methods' do
    describe '.return_processing_reason' do
      context 'default refund reason present' do
        let!(:default_refund_reason) { create(:default_refund_reason) }

        it { expect(described_class.return_processing_reason).to eq(default_refund_reason) }
      end

      context 'default refund reason not present' do
        it 'creates a new refund reason on the fly' do
          expect(described_class.return_processing_reason).to be_present
          expect(described_class.return_processing_reason.name).to eq('Return processing')
        end
      end
    end

    describe '.order_canceled_reason' do
      context 'order canceled reason present' do
        let!(:refund_reason) { create(:refund_reason, name: 'Order Canceled') }

        it { expect(described_class.order_canceled_reason).to eq(refund_reason) }
      end

      context 'order canceled reason not present' do
        it 'creates a new refund reason on the fly' do
          expect(described_class.order_canceled_reason).to be_present
          expect(described_class.order_canceled_reason.name).to eq('Order Canceled')
        end
      end
    end

    describe '.shipment_canceled_reason' do
      context 'shipment canceled reason present' do
        let!(:refund_reason) { create(:refund_reason, name: 'Shipment Canceled') }

        it { expect(described_class.shipment_canceled_reason).to eq(refund_reason) }
      end

      context 'shipment canceled reason not present' do
        it 'creates a new refund reason on the fly' do
          expect(described_class.shipment_canceled_reason).to be_present
          expect(described_class.shipment_canceled_reason.name).to eq('Shipment Canceled')
        end
      end
    end
  end
end
