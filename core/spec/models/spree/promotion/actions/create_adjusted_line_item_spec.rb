require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustedLineItems, type: :model do
  let(:order) { create(:order) }
  let(:promotion) { Spree::Promotion.create(name: 'Free Line Item') }
  let(:action) { Spree::Promotion::Actions::CreateAdjustedLineItems.create(promotion: promotion) }
  let(:shirt) { create(:variant) }
  let(:mug) { create(:variant) }
  let(:payload) { { order: order } }
  let(:promotional_quantity) { 2 }
  let(:calculator) { action.calculator }

  def empty_stock(variant)
    variant.stock_items.update_all(backorderable: false)
    variant.stock_items.each(&:reduce_count_on_hand_to_zero)
  end

  describe "#perform" do
    before do
      action.promotion_action_line_items.create!(
        variant: shirt,
        quantity: 2
      )
    end

    context 'order is eligible' do
      context 'promotional line item not present' do
        subject { order.line_items.find_by_variant_id(shirt.id) }

        context 'line item amount is less than computed discount' do
          before do
            calculator.preferred_percent = 10.0
            calculator.save
            action.perform(payload)
            order.update_totals
          end

          it { expect(subject.quantity).to eq(promotional_quantity) }
          it 'expect promo_total to be equal to the amount computed by the calculator' do
            expect(subject.promo_total).to eq(calculator.compute(subject).round(2) * -1)
          end
        end

        context 'line item amount is more than computed discount' do
          before do
            calculator.preferred_percent = 110.0
            calculator.save
            action.perform(payload)
            order.update_totals
          end

          it { expect(subject.quantity).to eq(promotional_quantity) }
          it { expect(subject.promo_total).to eq(subject.amount.round(2) * -1) }
        end
      end

      context 'promotional line item quantity is less than promotion quantity' do
        let(:current_quantity) { promotional_quantity - 1 }

        before do
          order.contents.add(shirt, current_quantity)
        end

        subject { order.line_items.find_by_variant_id(shirt.id) }

        context 'line item amount is less than computed discount' do
          before do
            calculator.preferred_percent = 10.0
            calculator.save
            action.perform(payload)
            order.update_totals
          end

          it { expect(subject.quantity).to eq(promotional_quantity) }
          it 'expect promo_total to be equal to the amount computed by the calculator' do
            expect(subject.promo_total).to eq(calculator.compute(subject).round(2) * -1)
          end
        end

        context 'line item amount is more than computed discount' do
          before do
            calculator.preferred_percent = 110.0
            calculator.save
            action.perform(payload)
            order.update_totals
          end

          it { expect(subject.quantity).to eq(promotional_quantity) }
          it 'expect promo_total to be equal to the amount of the subject' do
            expect(subject.promo_total).to eq(subject.amount.round(2) * -1)
          end
        end
      end

      context 'promotional line item quantity is more than promotion quantity' do
        let(:current_quantity) { promotional_quantity + 1 }

        before do
          order.contents.add(shirt, current_quantity)
        end

        subject { order.line_items.find_by_variant_id(shirt.id) }

        context 'line item amount is less than computed discount' do
          before do
            calculator.preferred_percent = 10.0
            calculator.save
            action.perform(payload)
            order.update_totals
          end

          let(:calculator_amount) { calculator.compute(subject).round(2) }

          it { expect(subject.quantity).to eq(current_quantity) }
          it 'expect promo_total to be equal to the adjusted amount computed by the calculator' do
            expect(subject.promo_total).to eq(calculator_amount * -1 * promotional_quantity / subject.quantity)
          end
        end

        context 'line item amount is more than computed discount' do
          before do
            calculator.preferred_percent = 110.0
            calculator.save
            action.perform(payload)
            order.update_totals
          end

          it { expect(subject.quantity).to eq(current_quantity) }
          it 'expect promo_total to be equal to the adjusted amount of the subject' do
            expect(subject.promo_total).to eq(subject.amount.round(2) * -1 * promotional_quantity / subject.quantity)
          end
        end
      end

      context 'variant out of stock' do
        before do
          empty_stock(shirt)
          action.perform(payload)
          order.update_totals
        end

        subject { order.line_items.find_by_variant_id(mug.id) }

        it { expect(subject).to be_nil }
      end
    end
  end
end
