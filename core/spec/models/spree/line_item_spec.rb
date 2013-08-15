require 'spec_helper'

describe Spree::LineItem do
  let(:order) { create :order_with_line_items, line_items_count: 1 }
  let(:line_item) { order.line_items.first }

  context '#save' do
    it 'should update inventory, totals, and tax' do
      # Regression check for #1481
      line_item.order.should_receive(:create_tax_charge!)
      line_item.order.should_receive(:update!)
      line_item.quantity = 2
      line_item.save
    end

    it "updates a linked adjustment" do
      tax_rate = create(:tax_rate, :amount => 10)
      adjustment = create(:adjustment, :source => tax_rate)
      line_item.price = 10
      line_item.tax_category = tax_rate.tax_category
      line_item.adjustments << adjustment
      line_item.save
      line_item.reload.adjustment_total.should == 100
    end
  end

  context '#destroy' do
    # Regression test for #1481
    it "applies tax adjustments" do
      line_item.order.should_receive(:create_tax_charge!)
      line_item.destroy
    end

    it "fetches deleted products" do
      line_item.product.destroy
      expect(line_item.reload.product).to be_a Spree::Product
    end

    it "fetches deleted variants" do
      line_item.variant.destroy
      expect(line_item.reload.variant).to be_a Spree::Variant
    end
  end

  # Test for #3391
  context '#copy_price' do
    it "copies over a variant's prices" do
      line_item.price = nil
      line_item.cost_price = nil
      line_item.currency = nil
      line_item.copy_price
      variant = line_item.variant
      line_item.price.should == variant.price
      line_item.cost_price.should == variant.cost_price
      line_item.currency.should == variant.currency
    end
  end

  # Test for #3481
  context '#copy_tax_category' do
    it "copies over a variant's tax category" do
      line_item.tax_category = nil
      line_item.copy_tax_category
      line_item.tax_category.should == line_item.variant.product.tax_category
    end
  end

  describe '.currency' do
    it 'returns the globally configured currency' do
      line_item.currency == 'USD'
    end
  end

  describe ".money" do
    before do
      line_item.price = 3.50
      line_item.quantity = 2
    end

    it "returns a Spree::Money representing the total for this line item" do
      line_item.money.to_s.should == "$7.00"
    end
  end

  describe '.single_money' do
    before { line_item.price = 3.50 }
    it "returns a Spree::Money representing the price for one variant" do
      line_item.single_money.to_s.should == "$3.50"
    end
  end

  context "has inventory (completed order so items were already unstocked)" do
    let(:order) { Spree::Order.create }
    let(:variant) { create(:variant) }

    context "nothing left on stock" do
      before do
        variant.stock_items.update_all count_on_hand: 5, backorderable: false
        order.contents.add(variant, 5)
        order.create_proposed_shipments
        order.finalize!
      end

      it "allows to decrease item quantity" do
        line_item = order.line_items.first
        line_item.quantity -= 1
        line_item.target_shipment = order.shipments.first

        line_item.save
        expect(line_item).to have(0).errors_on(:quantity)
      end

      it "doesnt allow to increase item quantity" do
        line_item = order.line_items.first
        line_item.quantity += 2
        line_item.target_shipment = order.shipments.first

        line_item.save
        expect(line_item).to have(1).errors_on(:quantity)
      end
    end

    context "2 items left on stock" do
      before do
        variant.stock_items.update_all count_on_hand: 7, backorderable: false
        order.contents.add(variant, 5)
        order.create_proposed_shipments
        order.finalize!
      end

      it "allows to increase quantity up to stock availability" do
        line_item = order.line_items.first
        line_item.quantity += 2
        line_item.target_shipment = order.shipments.first

        line_item.save
        expect(line_item).to have(0).errors_on(:quantity)
      end

      it "doesnt allow to increase quantity over stock availability" do
        line_item = order.line_items.first
        line_item.quantity += 3
        line_item.target_shipment = order.shipments.first

        line_item.save
        expect(line_item).to have(1).errors_on(:quantity)
      end
    end
  end

  context "best promotion is always applied" do
    let(:source) do
      source = Spree::Promotion::Actions::CreateAdjustment.create
      calculator = Spree::Calculator::PerItem.create(:calculable => source)
      source.calculator = calculator
      source.save
      source
    end

    def create_adjustment(label, amount)
      create(:adjustment, :order      => order,
                          :adjustable => line_item,
                          :source     => source,
                          :amount     => amount,
                          :state      => "closed",
                          :label      => label,
                          :mandatory  => false)
    end

    it "should make all but the most valuable promotion adjustment ineligible, leaving non promotion adjustments alone" do
      create_adjustment("Promotion A", -100)
      create_adjustment("Promotion B", -200)
      create_adjustment("Promotion C", -300)
      create(:adjustment, :order => order,
                          :adjustable => line_item,
                          :source => nil,
                          :amount => -500,
                          :state => "closed",
                          :label => "Some other credit")
      line_item.adjustments.each {|a| a.update_column(:eligible, true)}

      line_item.save!
      line_item.adjustments.promotion.eligible.count.should == 1
      line_item.adjustments.promotion.eligible.first.label.should == 'Promotion C'
      assert line_item.promotion_credit_exists?(source)
    end

    context "multiple adjustments and the best one is not eligible" do
      let!(:promo_a) { create_adjustment("Promotion A", -100) }
      let!(:promo_c) { create_adjustment("Promotion C", -300) }

      before do
        promo_a.update_column(:eligible, true)
        promo_c.update_column(:eligible, false)
      end

      # regression for #3274
      it "still makes the previous best eligible adjustment valid" do
        line_item.save
        line_item.adjustments.promotion.first.label.should == 'Promotion A'
      end
    end

    it "should only leave one adjustment even if 2 have the same amount" do
      create_adjustment("Promotion A", -100)
      create_adjustment("Promotion B", -200)
      create_adjustment("Promotion C", -200)

      line_item.save

      line_item.adjustments.promotion.eligible.count.should == 1
      line_item.adjustments.promotion.eligible.first.amount.to_i.should == -200
    end
  end
end
