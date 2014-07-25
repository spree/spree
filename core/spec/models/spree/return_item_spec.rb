require 'spec_helper'

shared_examples "an invalid state transition" do |status, expected_status|
  let(:status) { status }

  it "cannot transition to #{expected_status}" do
    expect { subject }.to raise_error(StateMachine::InvalidTransition)
  end
end

describe Spree::ReturnItem do

  all_reception_statuses = Spree::ReturnItem.state_machines[:reception_status].states.map(&:name).map(&:to_s)
  all_acceptance_statuses = Spree::ReturnItem.state_machines[:acceptance_status].states.map(&:name).map(&:to_s)

  before do
    Spree::Order.any_instance.stub(return!: true)
  end

  describe '#receive!' do
    let(:now)            { Time.now }
    let(:inventory_unit) { create(:inventory_unit, state: 'shipped') }
    let(:return_item)    { create(:return_item, inventory_unit: inventory_unit) }

    before do
      inventory_unit.update_attributes!(state: 'shipped')
      return_item.update_attributes!(reception_status: 'awaiting')
    end

    subject { return_item.receive! }

    it 'returns the inventory unit' do
      subject
      expect(inventory_unit.reload.state).to eq 'returned'
    end

    context 'with a stock location' do
      let(:stock_item)      { inventory_unit.find_stock_item }
      let!(:customer_return) { create(:customer_return, return_items: [return_item], stock_location_id: inventory_unit.shipment.stock_location_id) }

      before do
        inventory_unit.update_attributes!(state: 'shipped')
        return_item.update_attributes!(reception_status: 'awaiting')
      end

      it 'increases the count on hand' do
        expect { subject }.to change { stock_item.reload.count_on_hand }.by(1)
      end

      context 'when variant does not track inventory' do
        before do
          inventory_unit.update_attributes!(state: 'shipped')
          inventory_unit.variant.update_attributes!(track_inventory: false)
          return_item.update_attributes!(reception_status: 'awaiting')
        end

        it 'does not increase the count on hand' do
          expect { subject }.to_not change { stock_item.reload.count_on_hand }
        end
      end
    end
  end

  describe "#display_pre_tax_amount" do
    let(:pre_tax_amount) { 21.22 }
    let(:return_item) { Spree::ReturnItem.new(pre_tax_amount: pre_tax_amount) }

    it "returns a Spree::Money" do
      return_item.display_pre_tax_amount.should == Spree::Money.new(pre_tax_amount)
    end
  end

  describe "reception_status state_machine" do
    subject(:return_item) { create(:return_item) }

    it "starts off in the awaiting state" do
      expect(return_item).to be_awaiting
    end
  end

  describe "acceptance_status state_machine" do
    subject(:return_item) { create(:return_item) }

    it "starts off in the not_received state" do
      expect(return_item).to be_not_received
    end
  end

  describe "#receive" do
    let(:return_item) { create(:return_item, reception_status: status) }

    subject { return_item.receive! }

    context "awaiting status" do
      let(:status) { 'awaiting' }

      before do
        return_item.inventory_unit.should_receive(:return!)
      end

      before { subject }

      it "transitions successfully" do
        expect(return_item).to be_received
      end
    end

    (all_reception_statuses - ['awaiting']).each do |invalid_transition_status|
      context "return_item has a reception status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'received'
      end
    end
  end

  describe "#cancel" do
    let(:return_item) { create(:return_item, reception_status: status) }

    subject { return_item.cancel! }

    context "awaiting status" do
      let(:status) { 'awaiting' }

      before { subject }

      it "transitions successfully" do
        expect(return_item).to be_cancelled
      end
    end

    (all_reception_statuses - ['awaiting']).each do |invalid_transition_status|
      context "return_item has a reception status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'cancelled'
      end
    end
  end

  describe "#give" do
    let(:return_item) { create(:return_item, reception_status: status) }

    subject { return_item.give! }

    context "awaiting status" do
      let(:status) { 'awaiting' }

      before { subject }

      it "transitions successfully" do
        expect(return_item).to be_given_to_customer
      end
    end

    (all_reception_statuses - ['awaiting']).each do |invalid_transition_status|
      context "return_item has a reception status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'give_to_customer'
      end
    end
  end

  describe "#accept" do
    let(:return_item) { create(:return_item, acceptance_status: status) }

    subject { return_item.accept! }

    context "not_received status" do
      let(:status) { 'not_received' }

      before { subject }

      it "transitions successfully" do
        expect(return_item).to be_accepted
      end
    end

    (all_acceptance_statuses - ['not_received']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'accepted'
      end
    end
  end

  describe "#reject" do
    let(:return_item) { create(:return_item, acceptance_status: status) }

    subject { return_item.reject! }

    context "not_received status" do
      let(:status) { 'not_received' }

      before { subject }

      it "transitions successfully" do
        expect(return_item).to be_rejected
      end
    end

    (all_acceptance_statuses - ['not_received']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'rejected'
      end
    end
  end

  describe "#require_manual_intervention" do
    let(:return_item) { create(:return_item, acceptance_status: status) }

    subject { return_item.require_manual_intervention! }

    context "not_received status" do
      let(:status) { 'not_received' }

      before { subject }

      it "transitions successfully" do
        expect(return_item).to be_manual_intervention_required
      end
    end

    (all_acceptance_statuses - ['not_received']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'manual_intervention_required'
      end
    end
  end
end
