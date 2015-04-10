require 'spec_helper'

# Regression tests for #2179
module Spree
  describe OrderMerger, type: :model do
    let(:variant) { create(:variant) }
    let(:order_1) { Spree::Order.create! }
    let(:order_2) { Spree::Order.create! }
    let(:user) { stub_model(Spree::LegacyUser, email: "spree@example.com") }
    let(:subject) { Spree::OrderMerger.new(order_1) }

    context "#merge!" do
      let(:variant) { create(:variant) }
      let(:order_1) { Spree::Order.create! }
      let(:order_2) { Spree::Order.create! }

      shared_examples '#merge!' do
        it "destroys the other order" do
          order_1.merge!(order_2)
          expect { order_2.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it "returns target order" do
          expect(order_1.merge!(order_2)).to be(order_1)
        end
      end

      context "merging together two orders with line items for the same variant" do
        include_examples '#merge!'

        before do
          order_1.contents.add(variant, 1)
          order_2.contents.add(variant, 1)
        end

        specify do
          order_1.merge!(order_2)
          expect(order_1.line_items.count).to eq(1)

          line_item = order_1.line_items.first!
          expect(line_item.quantity).to eq(2)
          expect(line_item.variant_id).to eq(variant.id)
        end
      end

      context "merging together two orders with different line items" do
        include_examples '#merge!'

        let(:variant_2) { create(:variant) }

        before do
          order_1.contents.add(variant, 1)
          order_2.contents.add(variant_2, 1)
        end

        specify do
          order_1.merge!(order_2)
          line_items = order_1.line_items
          expect(line_items.count).to eq(2)

          expect(order_1.item_count).to eq 2
          expect(order_1.item_total).to eq line_items.map(&:amount).sum

          # No guarantee on ordering of line items, so we do this:
          expect(line_items.pluck(:quantity)).to match_array([1, 1])
          expect(line_items.pluck(:variant_id)).to match_array([variant.id, variant_2.id])
        end
      end
    end
  end
end
