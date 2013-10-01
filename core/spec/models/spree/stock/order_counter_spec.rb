require 'spec_helper'

module Spree
  module Stock
    describe OrderCounter do
      let(:variant1) { mock_model(Spree::Variant) }
      let(:variant2) { mock_model(Spree::Variant) }
      let(:order) { order = mock_model(Spree::Order, line_items: [], inventory_units: [])
                    order.line_items << mock_model(Spree::LineItem, variant: variant1 , quantity: 2)
                    order.line_items << mock_model(Spree::LineItem, variant: variant2, quantity: 2)
                    order.inventory_units << mock_model(Spree::InventoryUnit, order: order, variant: variant1)
                    order.inventory_units << mock_model(Spree::InventoryUnit, order: order, variant: variant2)
                    order.inventory_units << mock_model(Spree::InventoryUnit, order: order, variant: variant2)
                    order }

      subject { OrderCounter.new(order) }

      its(:variants) { should eq [variant1, variant2] }
      its(:variants_with_remaining) { should eq [variant1] }
      it { should be_remaining }

      it 'counts ordered' do
        subject.ordered(variant1).should eq 2
        subject.ordered(variant2).should eq 2
      end

      it 'counts assigned' do
        subject.assigned(variant1).should eq 1
        subject.assigned(variant2).should eq 2
      end

      it 'counts remaining' do
        subject.remaining(variant1).should eq 1
        subject.remaining(variant2).should eq 0
      end


      # Regression test for #3744
      context "works with a persisted order" do
        let(:order) { create(:completed_order_with_totals, :line_items_count => 1) }
        let(:variant1) { order.variants.first }

        it 'does not raise NoMethodError for Order#inventory_units' do
          subject.ordered(variant1).should eq 1
        end
      end
    end
  end
end

