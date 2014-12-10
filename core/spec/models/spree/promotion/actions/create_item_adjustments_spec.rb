require 'spec_helper'

module Spree
  class Promotion
    module Actions
      describe CreateItemAdjustments, :type => :model do
        let(:order) { create(:order) }
        let(:promotion) { create(:promotion) }
        let(:action) { CreateItemAdjustments.new }
        let!(:line_item) { create(:line_item, :order => order) }
        let(:payload) { { order: order, promotion: promotion } }
        let(:calculator) { Calculator::FlatRate.new(preferred_amount: 10) }

        before do
          allow(action).to receive(:promotion).and_return(promotion)
          promotion.promotion_actions = [action]
          action.calculator = calculator
        end

        it_behaves_like 'an adjustment source'

        context "#perform" do
          # Regression test for #3966
          context "when calculator computes 0" do
            let(:calculator) { Calculator::FlatRate.new(preferred_amount: 0) }

            it "does not create an adjustment when calculator returns 0" do
              action.perform(payload)
              expect(action.reload.adjustments).to be_empty
            end
          end

          context "when calculator returns a non-zero value" do

            it "creates adjustment with item as adjustable" do
              action.perform(payload)
              expect(action.adjustments.count).to eq(1)
              expect(line_item.reload.adjustments).to eq(action.adjustments)
            end

            it "creates adjustment with self as source" do
              action.perform(payload)
              expect(line_item.reload.adjustments.first.source).to eq action
            end

            it "does not perform twice on the same item" do
              2.times { action.perform(payload) }
              expect(action.adjustments.count).to eq(1)
            end

            context "with products rules" do
              let!(:second_line_item) { create(:line_item, :order => order) }
              let(:rule) { double Spree::Promotion::Rules::Product }

              before do
                allow(promotion).to receive(:eligible_rules) { [rule] }
                allow(rule).to receive(:actionable?).and_return(true, false)
              end

              it "does not create adjustments for line_items not in product rule" do
                action.perform(payload)
                expect(action.adjustments.count).to eql 1
                expect(line_item.reload.adjustments).to match_array action.adjustments
                expect(second_line_item.reload.adjustments).to be_empty
              end
            end
          end
        end

        context "#compute_amount" do
          before { promotion.promotion_actions = [action] }

          context "when the adjustable is actionable" do
            it "calls compute on the calculator" do
              expect(action.calculator).to receive(:compute).with(line_item)
              action.compute_amount(line_item)
            end

            context "calculator returns amount greater than item total" do
              before do
                expect(action.calculator).to receive(:compute).with(line_item).and_return(300)
                allow(line_item).to receive_messages(amount: 100)
              end

              it "does not exceed it" do
                expect(action.compute_amount(line_item)).to eql(-100)
              end
            end
          end

          context "when the adjustable is not actionable" do
            before { allow(promotion).to receive(:line_item_actionable?) { false } }

            it 'returns 0' do
              expect(action.compute_amount(line_item)).to eql(0)
            end
          end
        end

      end
    end
  end
end
