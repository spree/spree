require 'spec_helper'

describe Spree::OrderContents do
  let(:order) { Spree::Order.new }
  let(:variant) { create(:variant) }

  subject { described_class.new(order) }

  context "#add" do
    context 'given quantity is not explicitly provided' do
      it 'should add one line item' do
        line_item = subject.add(variant)
        line_item.quantity.should == 1
        order.line_items.size.should == 1
      end
    end

    it 'should add line item if one does not exist' do
      line_item = subject.add(variant, 1)
      line_item.quantity.should == 1
      order.line_items.size.should == 1
    end

    it "should associate the variant's tax category" do
      line_item = subject.add(variant, 1)
      line_item.tax_category.should == variant.tax_category
    end

    it 'should update line item if one exists' do
      subject.add(variant, 1)
      line_item = subject.add(variant, 1)
      line_item.quantity.should == 2
      order.line_items.size.should == 1
    end

    it "should update order totals" do
      order.item_total.to_f.should == 0.00
      order.total.to_f.should == 0.00

      subject.add(variant, 1)

      order.item_total.to_f.should == 19.99
      order.total.to_f.should == 19.99
    end

    it "runs promotions" do
      subject.should_receive(:activate_cart_promotions)
      subject.add(variant, 1)
    end
  end

  context "#remove" do
    context "given an invalid variant" do
      it "raises an exception" do
        expect {
          subject.remove(variant, 1)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'given quantity is not explicitly provided' do
      it 'should remove one line item' do
        line_item = subject.add(variant, 3)
        subject.remove(variant)

        order.find_line_item_by_variant(variant).quantity.should == 2
      end
    end

    it 'should reduce line_item quantity if quantity is less the line_item quantity' do
      line_item = subject.add(variant, 3)
      subject.remove(variant, 1)

      order.find_line_item_by_variant(variant).quantity.should == 2
    end

    it 'should remove line_item if quantity matches line_item quantity' do
      subject.add(variant, 1)
      subject.remove(variant, 1)

      order.find_line_item_by_variant(variant).should be_nil
    end

    it "should update order totals" do
      order.item_total.to_f.should == 0.00
      order.total.to_f.should == 0.00

      subject.add(variant,2)

      order.item_total.to_f.should == 39.98
      order.total.to_f.should == 39.98

      subject.remove(variant,1)
      order.item_total.to_f.should == 19.99
      order.total.to_f.should == 19.99
    end

    it "runs promotions" do
      subject.add(variant, 1)
      subject.should_receive(:activate_cart_promotions)
      subject.remove(variant, 1)
    end
  end

  context "#activate_cart_promotions" do
    it "calls to PromotionHandler::Cart" do
      line_item = double(:line_item)
      Spree::PromotionHandler::Cart.should_receive(:new).with(order, line_item).and_return(handler = double)
      handler.should_receive(:activate)
      subject.activate_cart_promotions(line_item)
    end
  end

  context "update cart" do
    let!(:shirt) { subject.add variant, 1 }

    let(:params) do
      { line_items_attributes: {
        "0" => { id: shirt.id, quantity: 3 }
      } }
    end

    it "changes item quantity" do
      subject.update_cart params
      expect(shirt.reload.quantity).to eq 3
    end

    it "updates order totals" do
      expect {
        subject.update_cart params
      }.to change { subject.order.total }
    end

    context "submits item quantity 0" do
      let(:params) do
        { line_items_attributes: {
          "0" => { id: shirt.id, quantity: 0 }
        } }
      end

      it "removes item from order" do
        expect {
          subject.update_cart params
        }.to change { subject.order.line_items.count }
      end
    end

    it "ensures updated shipments" do
      expect(subject.order).to receive(:ensure_updated_shipments)
      subject.update_cart params
    end
  end

  context "completed order" do
    let(:order) { Spree::Order.create! state: 'complete', completed_at: Time.now }

    before { order.shipments.create! stock_location_id: variant.stock_location_ids.first }

    it "updates order payment state" do
      expect {
        subject.add variant
      }.to change { order.payment_state }

      expect {
        subject.remove variant
      }.to change { order.payment_state }
    end
  end
end
