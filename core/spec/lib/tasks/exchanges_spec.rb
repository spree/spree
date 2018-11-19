require 'spec_helper'

describe 'exchanges:charge_unreturned_items' do
  include_context 'rake'

  describe '#prerequisites' do
    it { expect(subject.prerequisites).to include('environment') }
  end

  context 'there are no unreturned items' do
    it { expect { subject.invoke }.not_to change { Spree::Order.count } }
  end

  context 'there are unreturned items' do
    let!(:order) { create(:shipped_order, line_items_count: 2) }
    let(:return_item_1) { create(:exchange_return_item, inventory_unit: order.inventory_units.first) }
    let(:return_item_2) { create(:exchange_return_item, inventory_unit: order.inventory_units.last) }
    let!(:rma) { create(:return_authorization, order: order, return_items: [return_item_1, return_item_2]) }
    let!(:tax_rate) { create(:tax_rate, zone: order.tax_zone, tax_category: return_item_2.exchange_variant.tax_category) }

    before do
      @original_expedited_exchanges_pref = Spree::Config[:expedited_exchanges]
      Spree::Config[:expedited_exchanges] = true
      Spree::StockItem.update_all(count_on_hand: 10)
      rma.save!
      Spree::Shipment.last.ship!
      return_item_1.receive!
      Timecop.travel travel_time
    end

    after do
      Timecop.return
      Spree::Config[:expedited_exchanges] = @original_expedited_exchanges_pref
    end

    context 'fewer than the config allowed days have passed' do
      let(:travel_time) { (Spree::Config[:expedited_exchanges_days_window] - 1).days }

      it 'does not create a new order' do
        expect { subject.invoke }.not_to change { Spree::Order.count }
      end
    end

    context 'more than the config allowed days have passed' do
      let(:travel_time) { (Spree::Config[:expedited_exchanges_days_window] + 1).days }

      it 'creates a new completed order' do
        expect { subject.invoke }.to change { Spree::Order.count }
        expect(Spree::Order.last).to be_completed
      end

      it 'moves the shipment for the unreturned items to the new order' do
        subject.invoke
        new_order = Spree::Order.last
        expect(new_order.shipments.count).to eq 1
        expect(return_item_2.reload.exchange_shipments.first.order).to eq Spree::Order.last
      end

      it 'creates line items on the order for the unreturned items' do
        subject.invoke
        expect(Spree::Order.last.line_items.map(&:variant)).to eq [return_item_2.exchange_variant]
      end

      it 'associates the exchanges inventory units with the new line items' do
        subject.invoke
        expect(return_item_2.reload.exchange_inventory_units.last.try(:line_item).try(:order)).to eq Spree::Order.last
      end

      it 'uses the credit card from the previous order' do
        subject.invoke
        new_order = Spree::Order.last
        expect(new_order.credit_cards).to be_present
        expect(new_order.credit_cards.first).to eq order.valid_credit_cards.first
      end

      it 'authorizes the order for the full amount of the unreturned items including taxes' do
        expect { subject.invoke }.to change { Spree::Payment.count }.by(1)
        new_order = Spree::Order.last
        expected_amount = return_item_2.reload.exchange_variant.price + new_order.additional_tax_total + new_order.included_tax_total
        expect(new_order.total).to eq expected_amount
        payment = new_order.payments.first
        expect(payment.amount).to eq expected_amount
        expect(payment).to be_pending
        expect(new_order.item_total).to eq return_item_2.reload.exchange_variant.price
      end

      it 'does not attempt to create a new order for the item more than once' do
        subject.invoke
        subject.reenable
        expect { subject.invoke }.not_to change { Spree::Order.count }
      end

      it 'associates the store of the original order with the exchange order' do
        allow_any_instance_of(Spree::Order).to receive(:store_id).and_return(123)

        expect(Spree::Order).to receive(:create!).once.with(hash_including(store_id: 123)) { |attrs| Spree::Order.new(attrs.except(:store_id)).tap(&:save!) }
        subject.invoke
      end

      context 'there is no card from the previous order' do
        let!(:credit_card) { create(:credit_card, user: order.user, default: true, gateway_customer_profile_id: 'BGS-123') }

        before { allow_any_instance_of(Spree::Order).to receive(:valid_credit_cards).and_return([]) }

        it "attempts to use the user's default card" do
          expect { subject.invoke }.to change { Spree::Payment.count }.by(1)
          new_order = Spree::Order.last
          expect(new_order.credit_cards).to be_present
          expect(new_order.credit_cards.first).to eq credit_card
        end
      end

      context 'it is unable to authorize the credit card' do
        before { allow_any_instance_of(Spree::Payment).to receive(:authorize!).and_raise(RuntimeError) }

        it 'raises an error with the order' do
          expect { subject.invoke }.to raise_error(UnableToChargeForUnreturnedItems)
        end
      end

      context 'the exchange inventory unit is not shipped' do
        before { return_item_2.reload.exchange_inventory_units.update_all(state: 'on hand') }

        it 'does not create a new order' do
          expect { subject.invoke }.not_to change { Spree::Order.count }
        end
      end

      context 'the exchange inventory unit has been returned' do
        before { return_item_2.reload.exchange_inventory_units.update_all(state: 'returned') }

        it 'does not create a new order' do
          expect { subject.invoke }.not_to change { Spree::Order.count }
        end
      end
    end
  end
end
