require 'spec_helper'

module Spree
  describe Spree::Order, type: :model do
    let(:order) { create(:order, total: 100, payment_total: 0) }

    context 'processing payments' do
      before do
        # So that Payment#purchase! is called during processing
        stub_store_preferences(capture_method: 'checkout')

        allow(order).to receive_message_chain(:line_items, :empty?).and_return(false)
      end

      it 'processes the checkout payment' do
        # The creation flow stores the gateway profile while the card number is
        # still in memory — row save alone no longer does.
        payment = create(:payment, amount: 100, order: order).tap(&:create_payment_profile)

        order.process_payments!
        order.update_statuses!
        expect(order.payment_state).to eq('paid')

        expect(payment.reload).to be_completed
      end

      context 'processes all checkout payments along with store credits' do
        context 'with store credits payment method auto capture turned on' do
          it 'order should be paid' do
            store_credit = create(:store_credit_payment, amount: 50, order: order)
            payment = create(:payment, amount: 50, order: order)

            expect(order).to receive(:unprocessed_payments).and_return([store_credit, payment]).at_least(:once)

            order.process_payments!
            order.update_statuses!
            expect(order.payment_state).to eq('paid')

            expect(payment).to be_completed
            expect(store_credit).to be_completed
          end
        end

        context 'with a store credit payment method captured manually' do
          let!(:payment) { create(:payment, order: order, amount: payment_amount).tap(&:create_payment_profile) }
          let!(:store_credit_payment) do
            create(
              :store_credit_payment,
              order: order,
              amount: store_credit_amount,
              payment_method: create(:store_credit_payment_method, capture_method: 'manual', store: payment.order.store)
            )
          end

          before do
            order.process_payments!
            order.update_statuses!

            expect(payment.reload).to be_completed
            expect(store_credit_payment.reload).to be_pending
          end

          context 'order payment status should be partially paid' do
            let!(:payment_amount) { 70.00 }
            let!(:store_credit_amount) { 30.00 }

            it do
              expect(order.payment_status).to eq('partially_paid')
              expect(order.outstanding_balance).to eq(30.00)
            end
          end

          context 'order payment status should be partially paid' do
            let!(:payment_amount) { 90.00 }
            let!(:store_credit_amount) { 10.00 }

            it do
              expect(order.payment_status).to eq('partially_paid')
              expect(order.outstanding_balance).to eq(10.00)
            end
          end
        end
      end

      it 'does not go over total for order' do
        payment_1 = create(:payment, amount: 50, order: order)
        payment_2 = create(:payment, amount: 50, order: order)
        payment_3 = create(:payment, amount: 50, order: order)
        allow(order).to receive(:unprocessed_payments).and_return([payment_1, payment_2, payment_3])

        order.process_payments!
        order.update_statuses!
        expect(order.payment_state).to eq('paid')

        expect(payment_1).to be_completed
        expect(payment_2).to be_completed
        expect(payment_3).to be_checkout
      end

      it 'does not use failed payments' do
        payment_1 = create(:payment, amount: 50, order: order)
        payment_2 = create(:payment, amount: 50, status: 'failed', order: order)
        allow(order).to receive(:pending_payments).and_return([payment_1])

        expect(payment_2).not_to receive(:process!)

        order.process_payments!
      end
    end

    context 'ensure source attributes stick around' do
      # For the reason of this test, please see spree/spree_gateway#132
      it 'does not have inverse_of defined' do
        expect(Spree::Order.reflections['payments'].options[:inverse_of]).to be_nil
      end

      it 'keeps source attributes after updating' do
        store = create(:store)
        persisted_order = create(:order, store: store)
        credit_card_payment_method = create(:credit_card_payment_method)
        attributes = {
          payments_attributes: [
            {
              payment_method_id: credit_card_payment_method.id,
              source_attributes: {
                name: 'Ryan Bigg',
                number: '41111111111111111111',
                expiry: '01 / 15',
                verification_value: '123'
              }
            }
          ]
        }

        persisted_order.update(attributes)
        expect(persisted_order.unprocessed_payments.last.source.number).to be_present
      end
    end

    context '#outstanding_balance' do
      it 'returns positive amount when payment_total is less than total' do
        order.payment_total = 20.20
        order.total = 30.30
        expect(order.outstanding_balance).to eq(10.10)
      end

      it 'returns negative amount when payment_total is greater than total' do
        order.total = 8.20
        order.payment_total = 10.20
        expect(order.outstanding_balance).to be_within(0.001).of(-2.00)
      end

      # Refunds — whatever triggered them — are netted out of payment_total by
      # the totals workflow, so the money handed back reappears as balance the
      # order no longer has covered. There is no separate reimbursement term.
      it 'treats a refund issued for a return as reducing what was paid' do
        order = create(:completed_order_with_totals)
        calculator = order.fulfillments.first.delivery_method.calculator

        calculator.set_preference(:amount, order.fulfillments.first.cost)
        calculator.save!

        order.payments << create(:payment, status: :completed, order: order, amount: order.total)
        return_record = create(:received_return, order: order, store: order.store)

        create(:refund, amount: 10, payment: order.payments.first, originator: return_record)
        order.recalculate_totals!

        expect(order.outstanding_balance).to eq 10
      end

      it 'treats a manual refund the same way' do
        order = create(:completed_order_with_totals)
        calculator = order.fulfillments.first.delivery_method.calculator

        calculator.set_preference(:amount, order.fulfillments.first.cost)
        calculator.save!

        order.payments << create(:payment, status: :completed, order: order, amount: order.total)

        create(:refund, amount: 10, payment: order.payments.first)
        order.recalculate_totals!

        expect(order.outstanding_balance).to eq 10
      end
    end

    context '#outstanding_balance?' do
      it 'is true when total greater than payment_total' do
        order.total = 10.10
        order.payment_total = 9.50
        expect(order.outstanding_balance?).to be true
      end

      it 'is true when total less than payment_total' do
        order.total = 8.25
        order.payment_total = 10.44
        expect(order.outstanding_balance?).to be true
      end

      it 'is false when total equals payment_total' do
        order.total = 10.10
        order.payment_total = 10.10
        expect(order.outstanding_balance?).to be false
      end
    end
  end
end
