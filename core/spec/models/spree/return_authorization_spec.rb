require 'spec_helper'

describe Spree::ReturnAuthorization do
  let(:order) { create(:shipped_order) }
  let(:stock_location) { create(:stock_location) }
  let(:rma_reason) { create(:return_authorization_reason) }
  let(:inventory_unit_1) { order.inventory_units.first }

  let(:variant) { order.variants.first }
  let(:return_authorization) do
    Spree::ReturnAuthorization.new(order: order,
      stock_location_id: stock_location.id,
      return_authorization_reason_id: rma_reason.id)
  end

  context "save" do
    let(:order) { Spree::Order.create }

    it "should be invalid when order has no inventory units" do
      return_authorization.save
      return_authorization.errors[:order].should == ["has no shipped units"]
    end
  end

  describe ".before_create" do
    describe "#generate_number" do
      context "number is assigned" do
        let(:return_authorization) { Spree::ReturnAuthorization.new(number: '123') }

        it "should return the assigned number" do
          return_authorization.save
          return_authorization.number.should == '123'
        end
      end

      context "number is not assigned" do
        let(:return_authorization) { Spree::ReturnAuthorization.new(number: nil) }

        before { return_authorization.stub valid?: true }

        it "should assign number with random RA number" do
          return_authorization.save
          return_authorization.number.should =~ /RA\d{9}/
        end
      end
    end
  end

  context "#currency" do
    before { order.stub(:currency) { "ABC" } }
    it "returns the order currency" do
      return_authorization.currency.should == "ABC"
    end
  end

  describe "#pre_tax_total" do
    let(:pre_tax_amount_1) { 15.0 }
    let!(:return_item_1) { create(:return_item, return_authorization: return_authorization, pre_tax_amount: pre_tax_amount_1) }

    let(:pre_tax_amount_2) { 50.0 }
    let!(:return_item_2) { create(:return_item, return_authorization: return_authorization, pre_tax_amount: pre_tax_amount_2) }

    let(:pre_tax_amount_3) { 5.0 }
    let!(:return_item_3) { create(:return_item, return_authorization: return_authorization, pre_tax_amount: pre_tax_amount_3) }

    subject { return_authorization.pre_tax_total }

    it "sums it's associated return_item's pre-tax amounts" do
      subject.should eq (pre_tax_amount_1 + pre_tax_amount_2 + pre_tax_amount_3)
    end
  end

  describe "#display_pre_tax_total" do
    it "returns a Spree::Money" do
      return_authorization.stub(pre_tax_total: 21.22)
      return_authorization.display_pre_tax_total.should == Spree::Money.new(21.22)
    end
  end

  describe "#refundable_amount" do
    let(:weighted_line_item_pre_tax_amount) { 5.0 }
    let(:line_item_count)                   { return_authorization.order.line_items.count }

    subject { return_authorization.refundable_amount }

    before do
      return_authorization.order.line_items.update_all(pre_tax_amount: weighted_line_item_pre_tax_amount)
      return_authorization.order.update_attribute(:promo_total, promo_total)
    end

    context "no promotions" do
      let(:promo_total) { 0.0 }
      it "returns the pre-tax line item total" do
        subject.should eq (weighted_line_item_pre_tax_amount * line_item_count)
      end
    end

    context "promotions" do
      let(:promo_total) { -10.0 }
      it "returns the pre-tax line item total minus the order level promotion value" do
        subject.should eq (weighted_line_item_pre_tax_amount * line_item_count) + promo_total
      end
    end
  end

  describe "#customer_returned_items?" do
    before do
      Spree::Order.any_instance.stub(return!: true)
    end

    subject { return_authorization.customer_returned_items? }

    context "has associated customer returns" do
      let(:customer_return) { create(:customer_return) }
      let(:return_authorization) { customer_return.return_authorizations.first }

      it "returns true" do
        expect(subject).to eq true
      end
    end

    context "does not have associated customer returns" do
      let(:return_authorization) { create(:return_authorization) }

      it "returns false" do
        expect(subject).to eq false
      end
    end
  end

  describe 'cancel_return_items' do
    let(:return_authorization) { create(:return_authorization) }
    let(:order) { return_authorization.order }
    let!(:return_item) { return_authorization.return_items.create!(inventory_unit: order.inventory_units.first) }

    subject {
      return_authorization.cancel!
    }

    it 'cancels the associated return items' do
      subject
      expect(return_item.reception_status).to eq 'cancelled'
    end
  end
end
