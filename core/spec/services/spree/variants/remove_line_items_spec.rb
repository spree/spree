require 'spec_helper'

module Spree
  describe Variants::RemoveLineItems do
    subject { described_class }

    describe '#call' do
      let(:variant) { create(:variant) }

      context 'when all order states allows to remove line items' do
        let!(:orders) { create_list(:order_with_line_items, 3) }

        before do
          orders.each { |order| order.line_items.take.update(variant: variant) }
        end

        it 'schedules a Spree::LineItems::RemoveFromOrderJob for each order' do
          expect(Spree::Variants::RemoveLineItemJob).to receive(:perform_later).with(line_item: orders.first.line_items.take).once
          expect(Spree::Variants::RemoveLineItemJob).to receive(:perform_later).with(line_item: orders.second.line_items.take).once
          expect(Spree::Variants::RemoveLineItemJob).to receive(:perform_later).with(line_item: orders.third.line_items.take).once

          subject.call(variant: variant)
        end
      end

      context 'when none of order states allow to remove line items' do
        let!(:orders) { create_list(:order_with_line_items, 3, state: 'complete') }

        before do
          orders.each { |order| order.line_items.take.update(variant: variant) }
        end

        it 'does not schedule a Spree::LineItems::RemoveFromOrderJob for each order' do
          expect(Spree::Variants::RemoveLineItemJob).not_to receive(:perform_later)
        end
      end

      context 'when some of order states allow to remove line items' do
        let!(:pending_orders) { create_list(:order_with_line_items, 3, state: 'address') }
        let!(:cancelled_orders) { create_list(:order_with_line_items, 3, state: 'canceled') }

        before do
          pending_orders.each { |order| order.line_items.take.update(variant: variant) }
          cancelled_orders.each { |order| order.line_items.take.update(variant: variant) }
        end

        it 'schedules a Spree::LineItems::RemoveFromOrderJob for each pending order' do
          expect(Spree::Variants::RemoveLineItemJob).to receive(:perform_later).with(line_item: pending_orders.first.line_items.take).once
          expect(Spree::Variants::RemoveLineItemJob).to receive(:perform_later).with(line_item: pending_orders.second.line_items.take).once
          expect(Spree::Variants::RemoveLineItemJob).to receive(:perform_later).with(line_item: pending_orders.third.line_items.take).once

          subject.call(variant: variant)
        end

        it 'does not schedule a Spree::LineItems::RemoveFromOrderJob for each cancelled order' do
          expect(Spree::Variants::RemoveLineItemJob).not_to receive(:perform_later).with(line_item: cancelled_orders.first.line_items.take)
          expect(Spree::Variants::RemoveLineItemJob).not_to receive(:perform_later).with(line_item: cancelled_orders.second.line_items.take)
          expect(Spree::Variants::RemoveLineItemJob).not_to receive(:perform_later).with(line_item: cancelled_orders.third.line_items.take)

          subject.call(variant: variant)
        end
      end
    end
  end
end
