require 'spec_helper'

describe Spree::StockLevel, type: :model do
  subject { stock_location.stock_levels.order(:id).first }

  let(:stock_location) { create(:stock_location_with_items) }

  it_behaves_like 'metadata'
  it_behaves_like 'lifecycle events'

  # The rename would otherwise silently unsubscribe every webhook endpoint a
  # merchant had pointed at stock_item.*. Both names ship for one release.
  describe 'legacy stock_item events', events: true do
    let!(:stock_level) { create(:stock_level) }

    before do
      Spree::Events.reset!
      allow(Spree::Events).to receive(:enabled?).and_return(true)
    end

    after { Spree::Events.reset! }

    # One subscription set per example: calling this twice would count every
    # event twice over.
    def names_published
      received = []
      %w[stock_level stock_item].each do |prefix|
        %w[created updated deleted].each do |suffix|
          Spree::Events.subscribe("#{prefix}.#{suffix}", async: false) { |event| received << event.name }
        end
      end
      Spree::Events.activate!
      yield
      received
    end

    # Creating a level propagates more of them across the store's locations,
    # so what matters is that the two names come out in step.
    it 'publishes created under both names' do
      names = names_published { create(:stock_level) }

      expect(names).to include('stock_level.created', 'stock_item.created')
      expect(names.count('stock_item.created')).to eq(names.count('stock_level.created'))
    end

    it 'publishes updated under both names' do
      names = names_published { stock_level.update!(backorderable: !stock_level.backorderable) }

      expect(names).to contain_exactly('stock_level.updated', 'stock_item.updated')
    end

    it 'publishes deleted under both names' do
      names = names_published { stock_level.destroy! }

      expect(names).to contain_exactly('stock_level.deleted', 'stock_item.deleted')
    end

    it 'carries the same payload on both' do
      payloads = {}
      %w[stock_level.created stock_item.created].each do |name|
        Spree::Events.subscribe(name, async: false) { |event| payloads[name] = event.payload }
      end
      Spree::Events.activate!

      create(:stock_level)

      expect(payloads['stock_item.created']).to eq(payloads['stock_level.created'])
    end

    # The legacy twin follows whatever the real name did, so the touch-only
    # guard in Publishable is not defeated by publishing around it.
    it 'stays silent on a touch-only save' do
      names = names_published { stock_level.touch }

      expect(names).to be_empty
    end

    it 'leaves events this model does not own alone' do
      received = []
      Spree::Events.subscribe('stock_item.custom', async: false) { |event| received << event.name }
      Spree::Events.activate!

      stock_level.publish_event('stock_level.custom')

      expect(received).to be_empty
    end
  end

  it 'maintains the count on hand for a variant' do
    expect(subject.count_on_hand).to eq 10
  end

  it "can return the stock item's variant's name" do
    expect(subject.variant_name).to eq(subject.variant.name)
  end

  context 'available to be included in shipment' do
    context 'has stock' do
      it { expect(subject).to be_available }
    end

    context 'backorderable' do
      before { subject.backorderable = true }

      it { expect(subject).to be_available }
    end

    context 'no stock and not backorderable' do
      before do
        subject.backorderable = false
        allow(subject).to receive_messages(count_on_hand: 0)
      end

      it { expect(subject).not_to be_available }
    end
  end

  describe 'reduce_count_on_hand_to_zero' do
    context 'when count_on_hand > 0' do
      before do
        subject.update_column('count_on_hand', 4)
        subject.reduce_count_on_hand_to_zero
      end

      it { expect(subject.count_on_hand).to eq(0) }
    end

    context 'when count_on_hand > 0' do
      before do
        subject.update_column('count_on_hand', -4)
        @count_on_hand = subject.count_on_hand
        subject.reduce_count_on_hand_to_zero
      end

      it { expect(subject.count_on_hand).to eq(@count_on_hand) }
    end
  end

  context 'adjust count_on_hand' do
    let!(:current_on_hand) { subject.count_on_hand }

    it 'is updated pessimistically' do
      copy = Spree::StockLevel.find(subject.id)

      subject.adjust_count_on_hand(5)
      expect(subject.count_on_hand).to eq(current_on_hand + 5)

      expect(copy.count_on_hand).to eq(current_on_hand)
      copy.adjust_count_on_hand(5)
      expect(copy.count_on_hand).to eq(current_on_hand + 10)
    end

    context 'item out of stock (by five items)' do
      context 'when stock received is insufficient to fulfill backorders' do
        let(:inventory_unit)       { double('InventoryUnit') }
        let(:inventory_unit_2)     { double('InventoryUnit2') }
        let(:split_inventory_unit) { double('SplitInventoryUnit') }

        before do
          allow(subject).to receive_messages(backordered_inventory_units: [inventory_unit, inventory_unit_2])
          allow(split_inventory_unit).to receive_messages(quantity: 3)
          allow(inventory_unit).to receive_messages(quantity: 4, split_inventory!: split_inventory_unit)
          allow(inventory_unit_2).to receive_messages(quantity: 1)
          subject.update_column(:count_on_hand, -5)
        end

        it 'splits inventory to fulfill partial backorder' do
          expect(inventory_unit_2).not_to receive(:split_inventory!)

          expect(split_inventory_unit).to receive(:fill_backorder)
          expect(inventory_unit).not_to receive(:fill_backorder)
          expect(inventory_unit_2).not_to receive(:fill_backorder)

          subject.adjust_count_on_hand(3)
          expect(subject.count_on_hand).to eq(-2)
        end
      end
    end

    context 'item out of stock (by two items)' do
      let(:inventory_unit) { double('InventoryUnit') }
      let(:inventory_unit_2) { double('InventoryUnit2') }

      before do
        allow(subject).to receive_messages(backordered_inventory_units: [inventory_unit, inventory_unit_2])
        allow(inventory_unit).to receive_messages(quantity: 1)
        allow(inventory_unit_2).to receive_messages(quantity: 1)
        subject.update_column(:count_on_hand, -2)
      end

      # Regression test for #3755
      it 'processes existing backorders, even with negative stock' do
        expect(inventory_unit).to receive(:fill_backorder)
        expect(inventory_unit_2).not_to receive(:fill_backorder)
        subject.adjust_count_on_hand(1)
        expect(subject.count_on_hand).to eq(-1)
      end

      # Test for #3755. Only a departure may drive the shelf further below
      # zero now, so this states the kind that is doing the writing.
      it 'does not process backorders when stock is adjusted negatively' do
        expect(inventory_unit).not_to receive(:fill_backorder)
        expect(inventory_unit_2).not_to receive(:fill_backorder)
        subject.applying_movement_kind = 'shipped'
        subject.adjust_count_on_hand(-1)
        expect(subject.count_on_hand).to eq(-3)
      end

      context 'adds new items' do
        before { allow(subject).to receive_messages(backordered_inventory_units: [inventory_unit, inventory_unit_2]) }

        it 'fills existing backorders' do
          expect(inventory_unit).to receive(:fill_backorder)
          expect(inventory_unit_2).to receive(:fill_backorder)

          subject.adjust_count_on_hand(3)
          expect(subject.count_on_hand).to eq(1)
        end
      end
    end
  end

  context 'set count_on_hand' do
    let!(:current_on_hand) { subject.count_on_hand }

    it 'is updated pessimistically' do
      copy = Spree::StockLevel.find(subject.id)

      subject.set_count_on_hand(5)
      expect(subject.count_on_hand).to eq(5)

      expect(copy.count_on_hand).to eq(current_on_hand)
      copy.set_count_on_hand(10)
      expect(copy.count_on_hand).to eq(current_on_hand)
    end

    context 'item out of stock (by two items)' do
      let(:inventory_unit) { double('InventoryUnit') }
      let(:inventory_unit_2) { double('InventoryUnit2') }

      before do
        subject.applying_movement_kind = 'shipped'
        subject.set_count_on_hand(-2)
        subject.applying_movement_kind = nil
      end

      it "doesn't process backorders" do
        expect(subject).not_to receive(:backordered_inventory_units)
      end

      context 'adds new items' do
        before do
          allow(subject).to receive_messages(backordered_inventory_units: [inventory_unit, inventory_unit_2])
          allow(inventory_unit).to receive_messages(quantity: 1)
          allow(inventory_unit_2).to receive_messages(quantity: 1)
        end

        it 'fills existing backorders' do
          expect(inventory_unit).to receive(:fill_backorder)
          expect(inventory_unit_2).to receive(:fill_backorder)

          subject.set_count_on_hand(1)
          expect(subject.count_on_hand).to eq(1)
        end
      end
    end
  end

  context 'with stock movements' do
    before { Spree::StockMovement.create(stock_level: subject, quantity: 1, kind: 'received') }

    it 'doesnt raise ReadOnlyRecord error' do
      expect { subject.destroy }.not_to raise_error
    end
  end

  context 'destroyed' do
    before { subject.destroy }

    it 'recreates stock item just fine' do
      expect do
        stock_location.stock_levels.create!(variant: subject.variant)
      end.not_to raise_error
    end

    it 'doesnt allow recreating more than one stock item at once' do
      stock_location.stock_levels.create!(variant: subject.variant)

      expect do
        stock_location.stock_levels.create!(variant: subject.variant)
      end.to raise_error(StandardError)
    end
  end

  describe '#after_save' do
    before do
      subject.variant.update_column(:updated_at, 1.day.ago)
    end

    context 'binary_inventory_cache is set to false (default)' do
      context 'in_stock? changes' do
        it 'touches its variant' do
          expect do
            subject.adjust_count_on_hand(subject.count_on_hand * -1)
          end.to change { subject.variant.reload.updated_at }
        end
      end

      context 'in_stock? does not change' do
        it 'touches its variant' do
          expect do
            subject.adjust_count_on_hand((subject.count_on_hand * -1) + 1)
          end.to change { subject.variant.reload.updated_at }
        end
      end
    end

    context 'binary_inventory_cache is set to true' do
      before { Spree::Config.binary_inventory_cache = true }

      context 'in_stock? changes' do
        it 'touches its variant' do
          expect do
            subject.adjust_count_on_hand(subject.count_on_hand * -1)
          end.to change { subject.variant.reload.updated_at }
        end
      end

      context 'in_stock? does not change' do
        it 'does not touch its variant' do
          expect do
            subject.adjust_count_on_hand((subject.count_on_hand * -1) + 1)
          end.not_to change { subject.variant.reload.updated_at }
        end
      end

      context 'when a new stock location is added' do
        it 'touches its variant' do
          expect do
            perform_enqueued_jobs { create(:stock_location, propagate_all_variants: true) }
          end.to change { subject.variant.reload.updated_at }
        end
      end
    end
  end

  describe '#after_touch' do
    it 'touches its variant' do
      Timecop.scale(1000) do
        expect do
          subject.touch
        end.to change { subject.variant.updated_at }
      end
    end
  end

  # Regression test for #4651
  context 'variant' do
    it 'can be found even if the variant is deleted' do
      subject.variant.destroy
      expect(subject.reload.variant).not_to be_nil
    end
  end

  describe 'validations' do
    describe 'count_on_hand' do
      # How far below zero a level may go is decided by the movement kind
      # applying the change, not by the variant's backorder settings — an
      # oversell lives in allocated_count now, not in a negative shelf.
      shared_examples_for 'valid count_on_hand' do
        before { subject.save }

        it 'has no errors on count_on_hand' do
          expect(subject.errors[:count_on_hand]).to be_empty
        end
      end

      shared_examples_for 'not valid count_on_hand' do
        before { subject.save }

        it 'has an error on count_on_hand' do
          expect(subject.errors[:count_on_hand]).to include 'must be greater than or equal to 0'
        end
      end

      context 'when count_on_hand did not change' do
        it_behaves_like 'valid count_on_hand'
      end

      context 'when count_on_hand stays at or above zero' do
        before do
          subject.update_column(:count_on_hand, 3)
          subject.count_on_hand = 1
        end

        it_behaves_like 'valid count_on_hand'
      end

      context 'when count_on_hand rises while still negative' do
        before do
          subject.update_column(:count_on_hand, -3)
          subject.count_on_hand = -1
        end

        it_behaves_like 'valid count_on_hand'
      end

      context 'when count_on_hand is driven below zero' do
        before do
          subject.update_column(:count_on_hand, 3)
          subject.count_on_hand = -3
        end

        it_behaves_like 'not valid count_on_hand'

        context 'and the variant is backorderable' do
          before { subject.backorderable = true }

          it_behaves_like 'not valid count_on_hand'
        end

        context 'and the variant is a pre-order' do
          before { allow(subject.variant).to receive(:preorder?).and_return(true) }

          it_behaves_like 'not valid count_on_hand'
        end

        context 'and a departure is what is writing it' do
          before { subject.applying_movement_kind = 'shipped' }

          it_behaves_like 'valid count_on_hand'
        end
      end
    end
  end

  describe 'allocation counters' do
    subject { create(:stock_level, adjust_count_on_hand: false) }

    describe '#adjust_allocated_count' do
      it 'moves the promise in both directions' do
        subject.adjust_allocated_count(4)
        expect(subject.reload.allocated_count).to eq(4)

        subject.adjust_allocated_count(-3)
        expect(subject.reload.allocated_count).to eq(1)
      end
    end

    describe '#release_allocated_count' do
      it 'withdraws only what was promised' do
        subject.adjust_allocated_count(2)

        subject.release_allocated_count(5)

        expect(subject.reload.allocated_count).to eq(0)
      end
    end

    describe '#available_count' do
      it 'is the shelf minus the promise' do
        subject.update_columns(count_on_hand: 10, allocated_count: 4)

        expect(subject.available_count).to eq(6)
      end
    end

    describe '#in_stock?' do
      it 'is false once every unit is promised' do
        subject.update_columns(count_on_hand: 2, allocated_count: 2)

        expect(subject).not_to be_in_stock
      end

      it 'is true while unpromised units remain' do
        subject.update_columns(count_on_hand: 2, allocated_count: 1)

        expect(subject).to be_in_stock
      end
    end
  end

  describe 'scopes' do
    context '.with_active_stock_location' do
      let(:stock_levels_with_active_location) { Spree::StockLevel.with_active_stock_location }

      context 'when stock location is active' do
        before { stock_location.update_column(:active, true) }

        it { expect(stock_levels_with_active_location).to include(subject) }
      end

      context 'when stock location is inactive' do
        before { stock_location.update_column(:active, false) }

        it { expect(stock_levels_with_active_location).not_to include(subject) }
      end
    end

    describe '.for_store' do
      let(:store) { @default_store }
      let(:other_store) { create(:store) }
      let(:product_in_store) { create(:product, store: store) }
      let(:product_in_other_store) { create(:product, store: other_store) }

      let!(:in_store_item) do
        create(:stock_level, variant: product_in_store.default_variant, stock_location: stock_location)
      end
      let!(:other_store_item) do
        create(:stock_level, variant: product_in_other_store.default_variant, stock_location: stock_location)
      end

      it 'returns stock items for variants of products owned by the store' do
        expect(described_class.for_store(store)).to include(in_store_item)
      end

      it 'excludes stock items for products owned by another store' do
        expect(described_class.for_store(store)).not_to include(other_store_item)
      end
    end
  end
end
