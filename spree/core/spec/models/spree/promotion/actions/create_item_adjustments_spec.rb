require 'spec_helper'

module Spree
  class Promotion
    module Actions
      describe CreateItemAdjustments, type: :model do
        let(:order) { create(:order) }
        let(:promotion) { create(:promotion) }
        let(:action) { CreateItemAdjustments.new }
        let!(:line_item) { create(:line_item, order: order) }
        let(:payload) { { order: order, promotion: promotion } }

        before do
          allow(action).to receive(:promotion).and_return(promotion)
          promotion.promotion_actions = [action]
        end

        context '#perform' do
          # Regression test for #3966
          context 'when calculator computes 0' do
            before do
              allow(action).to receive_messages compute_amount: 0
            end

            it 'does not create a discount line when calculator returns 0' do
              expect(action.perform(payload)).to be(false)
              expect(action.discount_lines).to be_empty
            end
          end

          context 'when calculator returns a non-zero value' do
            before do
              promotion.promotion_actions = [action]
              allow(action).to receive_messages compute_amount: -10
            end

            it 'creates a discount line on the line item' do
              action.perform(payload)
              expect(action.discount_lines.count).to eq(1)
              expect(line_item.reload.discount_lines).to eq(action.discount_lines)
            end

            it 'links the discount line to the action and promotion' do
              action.perform(payload)

              discount_line = line_item.reload.discount_lines.first
              expect(discount_line.promotion_action).to eq(action)
              expect(discount_line.promotion).to eq(promotion)
            end

            it 'does not duplicate on repeated performs' do
              2.times { action.perform(payload) }
              expect(action.discount_lines.count).to eq(1)
            end

            context 'with products rules' do
              let!(:second_line_item) { create(:line_item, order: order) }
              let(:rule) { double Spree::Promotion::Rules::Product }

              before do
                allow(promotion).to receive(:eligible_rules) { [rule] }
                allow(rule).to receive(:actionable?).and_return(true, false)
              end

              it 'does not create discount lines for line_items not in product rule' do
                action.perform(payload)
                expect(action.discount_lines.count).to be 1
                expect(line_item.reload.discount_lines).to match_array action.discount_lines
                expect(second_line_item.reload.discount_lines).to be_empty
              end
            end
          end
        end

        context '#compute_amount' do
          before { promotion.promotion_actions = [action] }

          context 'when the adjustable is actionable' do
            it 'calls compute on the calculator' do
              allow(action.calculator).to receive(:compute).and_return(10)
              expect(action.calculator).to receive(:compute).with(line_item)
              action.compute_amount(line_item)
            end

            context 'calculator returns amount greater than item total' do
              before do
                expect(action.calculator).to receive(:compute).with(line_item).and_return(300)
                allow(line_item).to receive_messages(amount: 100)
              end

              it 'does not exceed it' do
                expect(action.compute_amount(line_item)).to be(-100)
              end
            end

            context 'given another promotion with an order-level discount' do
              let!(:line_item) { create :line_item, order: order, price: 15 }

              before do
                order.update_with_updater!

                create :promotion_with_order_adjustment, kind: :automatic
                Spree::PromotionHandler::Cart.new(order).activate

                allow(action.calculator).to receive(:compute).and_return(3)
              end

              it 'computes its own amount when room remains' do
                expect(action.compute_amount(line_item)).to eq(-3)
              end

              context 'when the remaining order value is smaller than the computed amount' do
                let!(:line_item) { create :line_item, order: order, price: 12 }

                it 'clamps to what the other discounts left' do
                  expect(action.compute_amount(line_item)).to eq(-2)
                end
              end

              context 'when other discounts already consume the whole order' do
                let!(:line_item) { create :line_item, order: order, price: 10 }

                it 'returns a non-negative amount (no line gets written)' do
                  expect(action.compute_amount(line_item)).to be >= 0
                end
              end
            end
          end

          context 'when the adjustable is not actionable' do
            before { allow(promotion).to receive(:line_item_actionable?).and_return(false) }

            it 'returns 0' do
              expect(action.compute_amount(line_item)).to be(0)
            end
          end
        end

        context '#destroy' do
          let(:other_promotion) { create(:promotion) }
          let!(:action) { CreateItemAdjustments.create!(promotion: promotion) }
          let!(:other_action) { CreateItemAdjustments.create!(promotion: other_promotion) }

          before { promotion.promotion_actions = [other_action] }

          it 'destroys discount lines for incomplete orders' do
            order = Order.create
            action.discount_lines.create!(label: 'Check', amount: -1, order: order, line_item: line_item)

            expect do
              action.destroy
            end.to change(DiscountLine, :count).by(-1)
          end

          it 'keeps discount lines on completed orders, still resolving the soft-deleted action' do
            order = Order.create(completed_at: Time.current)
            discount_line = action.discount_lines.create!(label: 'Check', amount: -1, order: order, line_item: line_item)

            expect do
              action.destroy
            end.not_to change(DiscountLine, :count)

            expect(discount_line.reload.promotion_action).to eq(action)
          end

          it 'doesnt mess with unrelated discount lines' do
            other_action.discount_lines.create!(label: 'Check', amount: -1, order: order, line_item: line_item)

            expect do
              action.destroy
            end.not_to change { other_action.discount_lines.count }
          end
        end
      end
    end
  end
end
