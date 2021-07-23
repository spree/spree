require 'spec_helper'

module Spree
  describe Cart::Destroy do
    subject { described_class.call order: order }

    context 'when order is given' do
      context 'when can be destroyed' do
        let(:order) { create(:order) }

        it 'returns success' do
          expect(subject.success?).to be true
        end

        it 'destroys the order' do
          expect(order.destroyed?).not_to be true

          subject

          expect(order.destroyed?).to be true
        end
      end

      context 'when cannot be destroyed' do
        let(:order) { create(:completed_order_with_totals) }

        it 'returns failure' do
          expect(subject.success?).to be false
          expect(subject.value).to eq Spree.t(:cannot_be_destroyed)
        end
      end
    end

    context 'when nil is given' do
      let(:order) { nil }

      before { subject }

      it 'returns failure' do
        expect(subject.success?).to be false
        expect(subject.value).to eq Spree.t(:cannot_be_destroyed)
      end
    end
  end
end
