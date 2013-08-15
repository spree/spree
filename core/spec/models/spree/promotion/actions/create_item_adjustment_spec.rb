require 'spec_helper'

module Spree
  class Promotion
    module Actions
      describe CreateItemAdjustment do
        let(:order) { create(:order) }
        let(:promotion) { create(:promotion) }
        let(:action) { CreateItemAdjustment.new }
        let!(:line_item) { create(:line_item, :order => order) }

        before { action.stub(:promotion => promotion) }

        context "#perform" do
          before { promotion.promotion_actions = [action] }

          it "creates adjustment with item as adjustable" do
            action.perform(line_item: line_item)
            line_item.reload.adjustments.should == action.adjustments
          end

          it "creates adjustment with self as source" do
            action.perform(line_item: line_item)
            expect(line_item.reload.adjustments.first.source).to eq action
          end

          it "does not perform twice on the same item" do
            2.times { action.perform(line_item: line_item) }
            action.adjustments.count.should == 1
          end
        end

        context "#compute_amount" do
          before { promotion.promotion_actions = [action] }

          it "calls compute on the calculator" do
            action.calculator.should_receive(:compute).with(line_item)
            action.compute_amount(line_item)
          end

          context "calculator returns amount greater than item total" do
            before do
              action.calculator.should_receive(:compute).with(line_item).and_return(300)
              line_item.stub(total: 100)
            end

            it "does not exceed it" do
              action.compute_amount(line_item).should eql(-100)
            end
          end
        end
      end
    end
  end
end
