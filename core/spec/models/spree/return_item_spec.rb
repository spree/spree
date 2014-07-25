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

    before { return_item.stub(:eligible_for_return?).and_return(true) }

    it 'returns the inventory unit' do
      subject
      expect(inventory_unit.reload.state).to eq 'returned'
    end

    context 'with a stock location' do
      let(:stock_item)      { inventory_unit.find_stock_item }
      let!(:customer_return) { create(:customer_return_without_return_items, return_items: [return_item], stock_location_id: inventory_unit.shipment.stock_location_id) }

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

    it "starts off in the pending state" do
      expect(return_item).to be_pending
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

  describe "#attempt_accept" do
    let(:return_item) { create(:return_item, acceptance_status: status) }
    let(:validator_errors) { {} }
    let(:validator_double) { double(errors: validator_errors) }

    subject { return_item.attempt_accept! }

    before do
      return_item.stub(:validator).and_return(validator_double)
    end

    context "pending status" do
      let(:status) { 'pending' }

      before do
        return_item.stub(:eligible_for_return?).and_return(true)
        subject
      end

      it "transitions successfully" do
        expect(return_item).to be_accepted
      end

      it "has no acceptance status errors" do
        expect(return_item.acceptance_status_errors).to be_empty
      end
    end

    (all_acceptance_statuses - ['pending']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'accepted'
      end
    end

    context "not eligible for return" do
      let(:status) { 'pending' }
      let(:validator_errors) { { number_of_days: "Return Item is outside the eligible time period" } }

      before do
        return_item.stub(:eligible_for_return?).and_return(false)
      end

      context "manual intervention required" do
        before do
          return_item.stub(:requires_manual_intervention?).and_return(true)
          subject
        end

        it "transitions to manual intervention required" do
          expect(return_item).to be_manual_intervention_required
        end

        it "sets the acceptance status errors" do
          expect(return_item.acceptance_status_errors).to eq validator_errors
        end
      end

      context "manual intervention not required" do
        before do
          return_item.stub(:requires_manual_intervention?).and_return(false)
          subject
        end

        it "transitions to rejected" do
          expect(return_item).to be_rejected
        end

        it "sets the acceptance status errors" do
          expect(return_item.acceptance_status_errors).to eq validator_errors
        end
      end
    end
  end

  describe "#reject" do
    let(:return_item) { create(:return_item, acceptance_status: status) }

    subject { return_item.reject! }

    context "pending status" do
      let(:status) { 'pending' }

      before { subject }

      it "transitions successfully" do
        expect(return_item).to be_rejected
      end

      it "has no acceptance status errors" do
        expect(return_item.acceptance_status_errors).to be_empty
      end
    end

    (all_acceptance_statuses - ['pending', 'manual_intervention_required']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'rejected'
      end
    end
  end

  describe "#accept" do
    let(:return_item) { create(:return_item, acceptance_status: status) }

    subject { return_item.accept! }

    context "pending status" do
      let(:status) { 'pending' }

      before { subject }

      it "transitions successfully" do
        expect(return_item).to be_accepted
      end

      it "has no acceptance status errors" do
        expect(return_item.acceptance_status_errors).to be_empty
      end
    end

    (all_acceptance_statuses - ['pending', 'manual_intervention_required']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'accepted'
      end
    end
  end

  describe "#require_manual_intervention" do
    let(:return_item) { create(:return_item, acceptance_status: status) }

    subject { return_item.require_manual_intervention! }

    context "pending status" do
      let(:status) { 'pending' }

      before { subject }

      it "transitions successfully" do
        expect(return_item).to be_manual_intervention_required
      end

      it "has no acceptance status errors" do
        expect(return_item.acceptance_status_errors).to be_empty
      end
    end

    (all_acceptance_statuses - ['pending']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like "an invalid state transition", invalid_transition_status, 'manual_intervention_required'
      end
    end
  end

  describe 'validity for reimbursements' do
    let(:return_item) { create(:return_item, acceptance_status: acceptance_status) }
    let(:acceptance_status) { 'pending' }

    before { return_item.reimbursement = build(:reimbursement) }

    subject { return_item }

    context 'when acceptance_status is accepted' do
      let(:acceptance_status) { 'accepted' }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when acceptance_status is accepted' do
      let(:acceptance_status) { 'pending' }

      it 'is valid' do
        expect(subject).to_not be_valid
        expect(subject.errors.messages).to eq({reimbursement: [I18n.t(:cannot_be_associated_unless_accepted, scope: 'activerecord.errors.models.spree/return_item.attributes.reimbursement')]})
      end
    end
  end
end
