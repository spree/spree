require 'spec_helper'

shared_examples 'an invalid state transition' do |status, expected_status|
  let(:status) { status }

  it "cannot transition to #{expected_status}" do
    expect { subject }.to raise_error(StateMachines::InvalidTransition)
  end
end

describe Spree::ReturnItem, type: :model do
  all_reception_statuses = Spree::ReturnItem.state_machines[:reception_status].states.map(&:name).map(&:to_s)
  all_acceptance_statuses = Spree::ReturnItem.state_machines[:acceptance_status].states.map(&:name).map(&:to_s)

  before do
    allow_any_instance_of(Spree::Order).to receive_messages(return!: true)
  end

  describe '#receive!' do
    subject { return_item.receive! }

    let(:now)            { Time.current }
    let(:inventory_unit) { create(:inventory_unit, state: 'shipped') }
    let(:return_item)    { create(:return_item, inventory_unit: inventory_unit) }

    before do
      inventory_unit.update_attributes!(state: 'shipped')
      return_item.update_attributes!(reception_status: 'awaiting')
      allow(return_item).to receive(:eligible_for_return?).and_return(true)
    end

    it 'returns the inventory unit' do
      subject
      expect(inventory_unit.reload.state).to eq 'returned'
    end

    it 'attempts to accept the return item' do
      expect(return_item).to receive(:attempt_accept)
      subject
    end

    context 'with a stock location' do
      let(:stock_item) { inventory_unit.find_stock_item }
      let!(:customer_return) { create(:customer_return_without_return_items, return_items: [return_item], stock_location_id: inventory_unit.shipment.stock_location_id) }

      before do
        inventory_unit.update_attributes!(state: 'shipped')
        return_item.update_attributes!(reception_status: 'awaiting')
      end

      it 'increases the count on hand' do
        expect { subject }.to change { stock_item.reload.count_on_hand }.by(1)
      end

      context 'when the variant is not resellable' do
        before { return_item.update_attributes(resellable: false) }
        it { expect { subject }.not_to change { stock_item.reload.count_on_hand } }
      end

      context 'when variant does not track inventory' do
        before do
          inventory_unit.update_attributes!(state: 'shipped')
          inventory_unit.variant.update_attributes!(track_inventory: false)
          return_item.update_attributes!(reception_status: 'awaiting')
        end

        it 'does not increase the count on hand' do
          expect { subject }.not_to change { stock_item.reload.count_on_hand }
        end
      end

      context 'when the restock_inventory preference is false' do
        before do
          Spree::Config[:restock_inventory] = false
        end

        it 'does not increase the count on hand' do
          expect { subject }.not_to change { stock_item.reload.count_on_hand }
        end
      end
    end
  end

  describe '#display_pre_tax_amount' do
    let(:pre_tax_amount) { 21.22 }
    let(:return_item) { build(:return_item, pre_tax_amount: pre_tax_amount) }

    it 'returns a Spree::Money' do
      expect(return_item.display_pre_tax_amount).to eq(Spree::Money.new(pre_tax_amount))
    end
  end

  describe '.default_refund_amount_calculator' do
    it 'defaults to the default refund amount calculator' do
      expect(Spree::ReturnItem.refund_amount_calculator).to eq Spree::Calculator::Returns::DefaultRefundAmount
    end
  end

  describe 'pre_tax_amount calculations on create' do
    let(:inventory_unit) { build(:inventory_unit) }

    before { subject.save! }

    context 'pre tax amount is not specified' do
      subject { build(:return_item, inventory_unit: inventory_unit) }

      context 'not an exchange' do
        it { expect(subject.pre_tax_amount).to eq Spree::Calculator::Returns::DefaultRefundAmount.new.compute(subject) }
      end

      context 'an exchange' do
        subject { build(:exchange_return_item) }

        it { expect(subject.pre_tax_amount).to eq 0.0 }
      end
    end

    context 'pre tax amount is specified' do
      subject { build(:return_item, inventory_unit: inventory_unit, pre_tax_amount: 100) }

      it { expect(subject.pre_tax_amount).to eq 100 }
    end
  end

  describe '.from_inventory_unit' do
    subject { Spree::ReturnItem.from_inventory_unit(inventory_unit) }

    let(:inventory_unit) { build(:inventory_unit) }

    context 'with a cancelled return item' do
      let!(:return_item) { create(:return_item, inventory_unit: inventory_unit, reception_status: 'cancelled') }

      it { is_expected.not_to be_persisted }
    end

    context 'with a non-cancelled return item' do
      let!(:return_item) { create(:return_item, inventory_unit: inventory_unit) }

      it { is_expected.to be_persisted }
    end
  end

  describe 'reception_status state_machine' do
    subject(:return_item) { create(:return_item) }

    it 'starts off in the awaiting state' do
      expect(return_item).to be_awaiting
    end
  end

  describe 'acceptance_status state_machine' do
    subject(:return_item) { create(:return_item) }

    it 'starts off in the pending state' do
      expect(return_item).to be_pending
    end
  end

  describe '#receive' do
    subject { return_item.receive! }

    let(:inventory_unit) { create(:inventory_unit, order: create(:shipped_order)) }
    let(:return_item)    { create(:return_item, reception_status: status, inventory_unit: inventory_unit) }

    context 'awaiting status' do
      let(:status) { 'awaiting' }

      before do
        expect(return_item.inventory_unit).to receive(:return!)
        subject
      end

      it 'transitions successfully' do
        expect(return_item).to be_received
      end
    end

    (all_reception_statuses - ['awaiting']).each do |invalid_transition_status|
      context "return_item has a reception status of #{invalid_transition_status}" do
        it_behaves_like 'an invalid state transition', invalid_transition_status, 'received'
      end
    end
  end

  describe '#cancel' do
    subject { return_item.cancel! }

    let(:return_item) { create(:return_item, reception_status: status) }

    context 'awaiting status' do
      let(:status) { 'awaiting' }

      before { subject }

      it 'transitions successfully' do
        expect(return_item).to be_cancelled
      end
    end

    (all_reception_statuses - ['awaiting']).each do |invalid_transition_status|
      context "return_item has a reception status of #{invalid_transition_status}" do
        it_behaves_like 'an invalid state transition', invalid_transition_status, 'cancelled'
      end
    end
  end

  describe '#give' do
    subject { return_item.give! }

    let(:return_item) { create(:return_item, reception_status: status) }

    context 'awaiting status' do
      let(:status) { 'awaiting' }

      before { subject }

      it 'transitions successfully' do
        expect(return_item).to be_given_to_customer
      end
    end

    (all_reception_statuses - ['awaiting']).each do |invalid_transition_status|
      context "return_item has a reception status of #{invalid_transition_status}" do
        it_behaves_like 'an invalid state transition', invalid_transition_status, 'give_to_customer'
      end
    end
  end

  describe '#attempt_accept' do
    subject { return_item.attempt_accept! }

    let(:return_item) { create(:return_item, acceptance_status: status) }
    let(:validator_errors) { {} }
    let(:validator_double) { double(errors: validator_errors) }

    before do
      allow(return_item).to receive(:validator).and_return(validator_double)
    end

    context 'pending status' do
      let(:status) { 'pending' }

      before do
        allow(return_item).to receive(:eligible_for_return?).and_return(true)
        subject
      end

      it 'transitions successfully' do
        expect(return_item).to be_accepted
      end

      it 'has no acceptance status errors' do
        expect(return_item.acceptance_status_errors).to be_empty
      end
    end

    (all_acceptance_statuses - ['accepted', 'pending']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like 'an invalid state transition', invalid_transition_status, 'accepted'
      end
    end

    context 'not eligible for return' do
      let(:status) { 'pending' }
      let(:validator_errors) { { number_of_days: 'Return Item is outside the eligible time period' } }

      before do
        allow(return_item).to receive(:eligible_for_return?).and_return(false)
      end

      context 'manual intervention required' do
        before do
          allow(return_item).to receive(:requires_manual_intervention?).and_return(true)
          subject
        end

        it 'transitions to manual intervention required' do
          expect(return_item).to be_manual_intervention_required
        end

        it 'sets the acceptance status errors' do
          expect(return_item.acceptance_status_errors).to eq validator_errors
        end
      end

      context 'manual intervention not required' do
        before do
          allow(return_item).to receive(:requires_manual_intervention?).and_return(false)
          subject
        end

        it 'transitions to rejected' do
          expect(return_item).to be_rejected
        end

        it 'sets the acceptance status errors' do
          expect(return_item.acceptance_status_errors).to eq validator_errors
        end
      end
    end
  end

  describe '#reject' do
    subject { return_item.reject! }

    let(:return_item) { create(:return_item, acceptance_status: status) }

    context 'pending status' do
      let(:status) { 'pending' }

      before { subject }

      it 'transitions successfully' do
        expect(return_item).to be_rejected
      end

      it 'has no acceptance status errors' do
        expect(return_item.acceptance_status_errors).to be_empty
      end
    end

    (all_acceptance_statuses - ['accepted', 'pending', 'manual_intervention_required']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like 'an invalid state transition', invalid_transition_status, 'rejected'
      end
    end
  end

  describe '#accept' do
    subject { return_item.accept! }

    let(:return_item) { create(:return_item, acceptance_status: status) }

    context 'pending status' do
      let(:status) { 'pending' }

      before { subject }

      it 'transitions successfully' do
        expect(return_item).to be_accepted
      end

      it 'has no acceptance status errors' do
        expect(return_item.acceptance_status_errors).to be_empty
      end
    end

    (all_acceptance_statuses - ['accepted', 'pending', 'manual_intervention_required']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like 'an invalid state transition', invalid_transition_status, 'accepted'
      end
    end
  end

  describe '#require_manual_intervention' do
    subject { return_item.require_manual_intervention! }

    let(:return_item) { create(:return_item, acceptance_status: status) }

    context 'pending status' do
      let(:status) { 'pending' }

      before { subject }

      it 'transitions successfully' do
        expect(return_item).to be_manual_intervention_required
      end

      it 'has no acceptance status errors' do
        expect(return_item.acceptance_status_errors).to be_empty
      end
    end

    (all_acceptance_statuses - ['accepted', 'pending', 'manual_intervention_required']).each do |invalid_transition_status|
      context "return_item has an acceptance status of #{invalid_transition_status}" do
        it_behaves_like 'an invalid state transition', invalid_transition_status, 'manual_intervention_required'
      end
    end
  end

  describe 'validity for reimbursements' do
    subject { return_item }

    let(:return_item) { create(:return_item, acceptance_status: acceptance_status) }
    let(:acceptance_status) { 'pending' }

    before { return_item.reimbursement = build(:reimbursement) }

    context 'when acceptance_status is accepted' do
      let(:acceptance_status) { 'accepted' }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when acceptance_status is accepted' do
      let(:acceptance_status) { 'pending' }

      it 'is valid' do
        expect(subject).not_to be_valid
        expect(subject.errors.messages).to eq(reimbursement: [I18n.t(:cannot_be_associated_unless_accepted, scope: 'activerecord.errors.models.spree/return_item.attributes.reimbursement')])
      end
    end
  end

  describe '#exchange_requested?' do
    context 'exchange variant exists' do
      before { allow(subject).to receive(:exchange_variant) { mock_model(Spree::Variant) } }
      it { expect(subject.exchange_requested?).to eq true }
    end
    context 'exchange variant does not exist' do
      before { allow(subject).to receive(:exchange_variant).and_return(nil) }
      it { expect(subject.exchange_requested?).to eq false }
    end
  end

  describe '#exchange_processed?' do
    context 'exchange inventory unit exists' do
      before { allow(subject).to receive(:exchange_inventory_units) { [mock_model(Spree::InventoryUnit)] } }
      it { expect(subject.exchange_processed?).to eq true }
    end
    context 'exchange inventory unit does not exist' do
      before { allow(subject).to receive(:exchange_inventory_units).and_return([]) }
      it { expect(subject.exchange_processed?).to eq false }
    end
  end

  describe '#exchange_required?' do
    context 'exchange has been requested and not yet processed' do
      before do
        allow(subject).to receive(:exchange_requested?).and_return(true)
        allow(subject).to receive(:exchange_processed?).and_return(false)
      end

      it { expect(subject.exchange_required?).to be true }
    end

    context 'exchange has not been requested' do
      before { allow(subject).to receive(:exchange_requested?).and_return(false) }
      it { expect(subject.exchange_required?).to be false }
    end

    context 'exchange has been requested and processed' do
      before do
        allow(subject).to receive(:exchange_requested?).and_return(true)
        allow(subject).to receive(:exchange_processed?).and_return(true)
      end
      it { expect(subject.exchange_required?).to be false }
    end
  end

  describe '#eligible_exchange_variants' do
    it 'uses the exchange variant calculator to compute possible variants to exchange for' do
      return_item = build(:return_item)
      expect(Spree::ReturnItem.exchange_variant_engine).to receive(:eligible_variants).with(return_item.variant)
      return_item.eligible_exchange_variants
    end
  end

  describe '.exchange_variant_engine' do
    it 'defaults to the same product calculator' do
      expect(Spree::ReturnItem.exchange_variant_engine).to eq Spree::ReturnItem::ExchangeVariantEligibility::SameProduct
    end
  end

  describe 'exchange pre_tax_amount' do
    let(:return_item) { build(:return_item) }

    context 'the return item is intended to be exchanged' do
      before do
        return_item.inventory_unit.variant.update_column(:track_inventory, false)
        return_item.exchange_variant = return_item.inventory_unit.variant
      end

      it do
        return_item.pre_tax_amount = 5.0
        return_item.save!
        expect(return_item.reload.pre_tax_amount).to eq 0.0
      end
    end

    context 'the return item is not intended to be exchanged' do
      it do
        return_item.pre_tax_amount = 5.0
        return_item.save!
        expect(return_item.reload.pre_tax_amount).to eq 5.0
      end
    end
  end

  describe '#build_default_exchange_inventory_unit' do
    subject { return_item.build_default_exchange_inventory_unit }

    let(:return_item) { build(:return_item) }

    context 'the return item is intended to be exchanged' do
      before { allow(return_item).to receive(:exchange_variant).and_return(mock_model(Spree::Variant)) }

      context 'an exchange inventory unit already exists' do
        before do
          allow(return_item).to receive(:exchange_inventory_units).and_return([mock_model(Spree::InventoryUnit)])
        end

        it { expect(subject).to be_nil }
      end

      context 'no exchange inventory unit exists' do
        it 'builds a pending inventory unit with references to the return item, variant, and previous inventory unit' do
          expect(subject.variant).to eq return_item.exchange_variant
          expect(subject.pending).to eq true
          expect(subject).not_to be_persisted
          expect(subject.original_return_item).to eq return_item
          expect(subject.line_item).to eq return_item.inventory_unit.line_item
          expect(subject.order).to eq return_item.inventory_unit.order
        end
      end
    end

    context 'the return item is not intended to be exchanged' do
      it { expect(subject).to be_nil }
    end
  end

  describe '#exchange_shipments' do
    it "returns the exchange inventory unit's shipment" do
      inventory_unit = build(:inventory_unit)
      subject.exchange_inventory_units << inventory_unit
      expect(subject.exchange_shipments).to include inventory_unit.shipment
    end
  end

  describe '#shipment' do
    it "returns the inventory unit's shipment" do
      inventory_unit = build(:inventory_unit)
      subject.inventory_unit = inventory_unit
      expect(subject.shipment).to eq inventory_unit.shipment
    end
  end

  describe 'inventory_unit uniqueness' do
    subject do
      build(:return_item,         return_authorization: old_return_item.return_authorization,
                                  inventory_unit: old_return_item.inventory_unit)
    end

    let!(:old_return_item) { create(:return_item, reception_status: old_reception_status) }
    let(:old_reception_status) { 'awaiting' }

    context 'with other awaiting return items exist for the same inventory unit' do
      let(:old_reception_status) { 'awaiting' }

      it 'cancels the others' do
        expect do
          subject.save!
        end.to change { old_return_item.reload.reception_status }.from('awaiting').to('cancelled')
      end

      it 'does not cancel itself' do
        subject.save!
        expect(subject).to be_awaiting
      end
    end

    context 'with other cancelled return items exist for the same inventory unit' do
      let(:old_reception_status) { 'cancelled' }

      it 'succeeds' do
        expect { subject.save! }.not_to raise_error
      end
    end

    context 'with other received return items exist for the same inventory unit' do
      let(:old_reception_status) { 'received' }

      it 'is invalid' do
        expect(subject).not_to be_valid
        expect(subject.errors.to_a).to eq ["Inventory unit #{subject.inventory_unit_id} has already been taken by return item #{old_return_item.id}"]
      end
    end

    context 'with other given_to_customer return items exist for the same inventory unit' do
      let(:old_reception_status) { 'given_to_customer' }

      it 'is invalid' do
        expect(subject).not_to be_valid
        expect(subject.errors.to_a).to eq ["Inventory unit #{subject.inventory_unit_id} has already been taken by return item #{old_return_item.id}"]
      end
    end
  end

  describe 'valid exchange variant' do
    subject { return_item }

    before  { subject.save }

    context "return item doesn't have an exchange variant" do
      let(:return_item) { create(:return_item) }

      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'return item has an exchange variant' do
      let(:return_item)      { create(:exchange_return_item) }
      let(:exchange_variant) { create(:on_demand_variant, product: return_item.inventory_unit.variant.product) }

      context 'the exchange variant is eligible' do
        before { return_item.exchange_variant = exchange_variant }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'the exchange variant is not eligible' do
        context 'new return item' do
          let(:return_item)      { build(:return_item) }
          let(:exchange_variant) { create(:variant, product: return_item.inventory_unit.variant.product) }

          before { return_item.exchange_variant = exchange_variant }

          it 'is invalid' do
            expect(subject).not_to be_valid
          end

          it 'adds an error message about the invalid exchange variant' do
            subject.valid?
            expect(subject.errors.to_a).to eq ['Invalid exchange variant.']
          end
        end

        context 'the exchange variant has been updated' do
          before do
            other_variant = create(:variant)
            return_item.exchange_variant_id = other_variant.id
            subject.valid?
          end

          it 'is invalid' do
            expect(subject).not_to be_valid
          end

          it 'adds an error message about the invalid exchange variant' do
            expect(subject.errors.to_a).to eq ['Invalid exchange variant.']
          end
        end

        context 'the exchange variant has not been updated' do
          before do
            other_variant = create(:variant)
            return_item.update_column(:exchange_variant_id, other_variant.id)
            return_item.reload
            subject.valid?
          end

          it 'is valid' do
            expect(subject).to be_valid
          end
        end
      end
    end
  end

  describe 'included tax in total' do
    let(:inventory_unit) { create(:inventory_unit, state: 'shipped') }
    let(:return_item) do
      create(
        :return_item,
        inventory_unit: inventory_unit,
        included_tax_total: 10
      )
    end

    it 'includes included tax total' do
      expect(return_item.pre_tax_amount).to eq 10
      expect(return_item.included_tax_total).to eq 10
      expect(return_item.total).to eq 20
    end
  end

  describe '#process_inventory_unit!' do
    subject { return_item.send(:process_inventory_unit!) }

    let(:inventory_unit) { create(:inventory_unit, state: 'shipped') }
    let(:return_item) { create(:return_item, inventory_unit: inventory_unit, reception_status: 'awaiting') }
    let!(:stock_item) { inventory_unit.find_stock_item }

    before { return_item.update_attributes!(reception_status: 'awaiting') }

    it { expect { subject }.to change(inventory_unit, :state).to('returned').from('shipped') }

    context 'stock should restock' do
      let(:stock_movement_attributes) do
        {
          stock_item_id: stock_item.id,
          quantity: 1,
          originator: return_item.return_authorization
        }
      end

      it { expect(subject).to eq(Spree::StockMovement.find_by(stock_movement_attributes)) }
    end

    context 'stock should not restock' do
      context 'return_item is not resellable' do
        before { return_item.resellable = false }
        it { expect(subject).to be_nil }
        it { expect { subject }.not_to change { stock_item.reload.count_on_hand } }
      end

      context 'variant should not track inventory' do
        before { return_item.variant.track_inventory = false }
        it { expect(subject).to be_nil }
        it { expect { subject }.not_to change { stock_item.reload.count_on_hand } }
      end

      context 'stock_item not present' do
        before { stock_item.destroy }
        it { expect(subject).to be_nil }
        it { expect { subject }.not_to change { stock_item.reload.count_on_hand } }
      end

      context 'when restock inventory preference false' do
        before { Spree::Config[:restock_inventory] = false }
        it { expect(subject).to be_nil }
        it { expect { subject }.not_to change { stock_item.reload.count_on_hand } }
      end
    end
  end
end
