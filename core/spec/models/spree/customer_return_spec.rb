require 'spec_helper'

describe Spree::CustomerReturn, :type => :model do
  before do
    allow_any_instance_of(Spree::Order).to receive_messages(return!: true)
  end

  describe ".validation" do
    describe "#must_have_return_authorization" do
      let(:customer_return)       { build(:customer_return) }

      let(:inventory_unit)  { build(:inventory_unit) }
      let(:return_item)     { build(:return_item, inventory_unit: inventory_unit) }

      subject { customer_return.valid? }

      before do
        customer_return.return_items << return_item
      end

      context "return item does not belong to return authorization" do
        before do
          return_item.return_authorization = nil
        end

        it "is not valid" do
          expect(subject).to eq false
        end

        it "adds an error message" do
          subject
          expect(customer_return.errors.full_messages).to include(Spree.t(:missing_return_authorization, item_name: inventory_unit.variant.name))
        end
      end

      context "return item belongs to return authorization" do
        it "is valid" do
          expect(subject).to eq true
        end
      end
    end

    describe "#return_items_belong_to_same_order" do
      let(:customer_return)       { build(:customer_return) }

      let(:first_inventory_unit)  { build(:inventory_unit) }
      let(:first_return_item)     { build(:return_item, inventory_unit: first_inventory_unit) }

      let(:second_inventory_unit) { build(:inventory_unit, order: second_order) }
      let(:second_return_item)    { build(:return_item, inventory_unit: second_inventory_unit) }

      subject { customer_return.valid? }

      before do
        customer_return.return_items << first_return_item
        customer_return.return_items << second_return_item
      end

      context "return items are part of different orders" do
        let(:second_order) { create(:order) }

        it "is not valid" do
          expect(subject).to eq false
        end

        it "adds an error message" do
          subject
          expect(customer_return.errors.full_messages).to include(Spree.t(:return_items_cannot_be_associated_with_multiple_orders))
        end
      end

      context "return items are part of the same order" do
        let(:second_order) { first_inventory_unit.order }

        it "is valid" do
          expect(subject).to eq true
        end
      end
    end
  end

  describe ".before_create" do
    describe "#generate_number" do
      context "number is assigned" do
        let(:customer_return) { Spree::CustomerReturn.new(number: '123') }

        it "should return the assigned number" do
          customer_return.save
          expect(customer_return.number).to eq('123')
        end
      end

      context "number is not assigned" do
        let(:customer_return) { Spree::CustomerReturn.new(number: nil) }

        before do
          allow(customer_return).to receive_messages(valid?: true, process_return!: true)
        end

        it "should assign number with random CR number" do
          customer_return.save
          expect(customer_return.number).to match(/CR\d{9}/)
        end
      end
    end
  end

  describe "#pre_tax_total" do
    let(:pre_tax_amount)  { 15.0 }
    let(:customer_return) { create(:customer_return, line_items_count: 2) }

    before do
      Spree::ReturnItem.where(customer_return_id: customer_return.id).update_all(pre_tax_amount: pre_tax_amount)
    end

    subject { customer_return.pre_tax_total }

    it "returns the sum of the return item's pre_tax_amount" do
      expect(subject).to eq (pre_tax_amount * 2)
    end
  end

  describe "#display_pre_tax_total" do
    let(:customer_return) { Spree::CustomerReturn.new }

    it "returns a Spree::Money" do
      allow(customer_return).to receive_messages(pre_tax_total: 21.22)
      expect(customer_return.display_pre_tax_total).to eq(Spree::Money.new(21.22))
    end
  end

  describe "#order" do
    let(:return_item) { create(:return_item) }
    let(:customer_return) { build(:customer_return, return_items: [return_item]) }

    subject { customer_return.order }

    it "returns the order associated with the return item's inventory unit" do
      expect(subject).to eq return_item.inventory_unit.order
    end
  end

  describe "#order_id" do
    subject { customer_return.order_id }

    context "return item is not associated yet" do
      let(:customer_return) { build(:customer_return) }

      it "is nil" do
        expect(subject).to be_nil
      end
    end

    context "has an associated return item" do
      let(:return_item) { create(:return_item) }
      let(:customer_return) { build(:customer_return, return_items: [return_item]) }

      it "is the return item's inventory unit's order id" do
        expect(subject).to eq return_item.inventory_unit.order.id
      end
    end
  end

  context ".after_save" do
    let(:inventory_unit)  { create(:inventory_unit, state: 'shipped', order: create(:shipped_order)) }
    let(:return_item)     { create(:return_item, inventory_unit: inventory_unit) }

    context "to the initial stock location" do

      it "should mark all inventory units are returned" do
        create(:customer_return_without_return_items, return_items: [return_item], stock_location_id: inventory_unit.shipment.stock_location_id)
        expect(inventory_unit.reload.state).to eq 'returned'
      end

      it "should update the stock item counts in the stock location" do
        expect do
          create(:customer_return_without_return_items, return_items: [return_item], stock_location_id: inventory_unit.shipment.stock_location_id)
        end.to change { inventory_unit.find_stock_item.count_on_hand }.by(1)
      end

      context 'with Config.track_inventory_levels == false' do
        before do
          Spree::Config.track_inventory_levels = false
          expect(Spree::StockItem).not_to receive(:find_by)
          expect(Spree::StockMovement).not_to receive(:create!)
        end

        it "should NOT update the stock item counts in the stock location" do
          count_on_hand = inventory_unit.find_stock_item.count_on_hand
          create(:customer_return_without_return_items, return_items: [return_item], stock_location_id: inventory_unit.shipment.stock_location_id)
          expect(inventory_unit.find_stock_item.count_on_hand).to eql count_on_hand
        end
      end
    end

    context "to a different stock location" do
      let(:new_stock_location) { create(:stock_location, :name => "other") }

      it "should update the stock item counts in new stock location" do
        expect {
          create(:customer_return_without_return_items, return_items: [return_item], stock_location_id: new_stock_location.id)
        }.to change {
          Spree::StockItem.where(variant_id: inventory_unit.variant_id, stock_location_id: new_stock_location.id).first.count_on_hand
        }.by(1)
      end

      it "should NOT raise an error when no stock item exists in the stock location" do
        inventory_unit.find_stock_item.destroy
        expect { create(:customer_return_without_return_items, return_items: [return_item], stock_location_id: new_stock_location.id) }.not_to raise_error
      end

      it "should not update the stock item counts in the original stock location" do
        count_on_hand = inventory_unit.find_stock_item.count_on_hand
        create(:customer_return_without_return_items, return_items: [return_item], stock_location_id: new_stock_location.id)
        expect(inventory_unit.find_stock_item.count_on_hand).to eq(count_on_hand)
      end
    end
  end

  describe '#fully_reimbursed?' do
    let(:customer_return) { create(:customer_return) }

    let!(:default_refund_reason) { Spree::RefundReason.find_or_create_by!(name: Spree::RefundReason::RETURN_PROCESSING_REASON, mutable: false) }

    subject { customer_return.fully_reimbursed? }

    context 'when some return items are undecided' do
      it { is_expected.to be false }
    end

    context 'when all return items are decided' do

      context 'when all return items are rejected' do
        before { customer_return.return_items.each(&:reject!) }

        it { is_expected.to be true }
      end

      context 'when all return items are accepted' do
        before { customer_return.return_items.each(&:accept!) }

        context 'when some return items have no reimbursement' do
          it { is_expected.to be false }
        end

        context 'when all return items have a reimbursement' do
          let!(:reimbursement) { create(:reimbursement, customer_return: customer_return) }

          context 'when some reimbursements are not reimbursed' do
            it { is_expected.to be false }
          end

          context 'when all reimbursements are reimbursed' do
            before { reimbursement.perform! }

            it { is_expected.to be true }
          end
        end
      end
    end
  end
end
