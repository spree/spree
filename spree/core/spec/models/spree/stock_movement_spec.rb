require 'spec_helper'

describe Spree::StockMovement, type: :model do
  # Note: StockMovement is marked as readonly after creation, so we only test the created event
  describe 'lifecycle events', events: true do
    describe 'stock_movement.created' do
      it 'publishes created event when record is created' do
        record = build(:stock_movement)
        expect(record).to receive(:publish_event).with('stock_movement.created')
        allow(record).to receive(:publish_event).with(anything)

        record.save!
      end
    end
  end

  describe 'Constants' do
    describe 'KINDS' do
      it 'names every movement kind' do
        expect(described_class::KINDS).to eq(%w[received allocated shipped released adjusted])
      end
    end

    describe 'QUANTITY_LIMITS[:max]' do
      it 'return 2**31 - 1' do
        expect(Spree::StockMovement::QUANTITY_LIMITS[:max]).to eq(2**31 - 1)
      end
    end

    describe 'QUANTITY_LIMITS[:min]' do
      it 'return -2**31' do
        expect(Spree::StockMovement::QUANTITY_LIMITS[:min]).to eq(-2**31)
      end
    end
  end

  describe 'validations' do
    let(:stock_level) { create(:stock_level, backorderable: false) }

    it 'requires a kind' do
      movement = build(:stock_movement, kind: nil, stock_level: stock_level)

      expect(movement).to be_invalid
      expect(movement.errors[:kind]).to be_present
    end

    it 'rejects an unknown kind' do
      movement = build(:stock_movement, kind: 'sold', stock_level: stock_level)

      expect(movement).to be_invalid
      expect(movement.errors[:kind]).to be_present
    end

    it 'rejects a zero quantity' do
      movement = build(:stock_movement, quantity: 0, stock_level: stock_level)

      expect(movement).to be_invalid
      expect(movement.errors[:quantity]).to be_present
    end

    it 'requires a reason for an adjustment' do
      movement = build(:stock_movement, kind: 'adjusted', reason: nil, stock_level: stock_level)

      expect(movement).to be_invalid
      expect(movement.errors[:reason]).to be_present

      movement.reason = 'Cycle count'
      expect(movement).to be_valid
    end

    it 'does not require a reason for any other kind' do
      expect(build(:stock_movement, kind: 'received', reason: nil, stock_level: stock_level)).to be_valid
    end

    # The old min_quantity guard is gone: how far below zero a level may go is
    # decided by the kind applying the change, not by the movement's size.
    it 'allows a quantity larger than the count on hand' do
      expect(build(:stock_movement, quantity: -11, stock_level: stock_level)).to be_valid
    end
  end

  describe 'Scope' do
    describe '.recent' do
      it 'orders chronologically by created at' do
        expect(Spree::StockMovement.recent.to_sql).
          to eq Spree::StockMovement.unscoped.order(created_at: :desc).to_sql
      end
    end

    describe 'kind scopes' do
      let(:stock_level) { create(:stock_level) }
      let!(:received) { create(:stock_movement, kind: 'received', quantity: 1, stock_level: stock_level) }
      let!(:allocated) { create(:stock_movement, kind: 'allocated', quantity: 1, stock_level: stock_level) }

      it 'filters by kind' do
        expect(described_class.received).to contain_exactly(received)
        expect(described_class.allocated).to contain_exactly(allocated)
        expect(described_class.shipped).to be_empty
      end

      it 'answers the matching predicate' do
        expect(received).to be_received
        expect(received).not_to be_allocated
      end
    end
  end

  describe 'whitelisted ransackable attributes' do
    it 'exposes the kind and every cause key' do
      expect(Spree::StockMovement.whitelisted_ransackable_attributes).to eq(
        %w[quantity kind reason created_at stock_level_id order_id fulfillment_id return_id
           exchange_id stock_transfer_id]
      )
    end
  end

  describe '.default_adjustment_reason' do
    it 'resolves in English whatever locale is active' do
      I18n.with_locale(:de) do
        expect(described_class.default_adjustment_reason).to eq('Manual adjustment')
      end
    end
  end

  describe 'Instance Methods' do
    let(:stock_location) { create(:stock_location_with_items) }
    let(:stock_level) { stock_location.stock_levels.order(:id).first }
    let(:stock_movement) { build(:stock_movement, stock_level: stock_level) }

    describe '.product' do
      it { expect(stock_movement.product).to eq(stock_level.variant.product) }
    end

    describe '.variant' do
      it { expect(stock_movement.variant).to eq(stock_level.variant) }
    end

    describe '#readonly?' do
      let(:stock_movement) { create(:stock_movement, stock_level: stock_level) }

      it 'does not update a persisted record' do
        expect { stock_movement.save }.to raise_error(ActiveRecord::ReadOnlyRecord)
      end
    end

    describe '#apply_to_stock_level' do
      context 'when track inventory levels is false' do
        before do
          stub_store_preferences(track_inventory_levels: false)
          stock_movement.quantity = 1
          stock_movement.save
          stock_level.reload
        end

        it 'does not update count on hand' do
          expect(stock_level.count_on_hand).to eq(10)
        end
      end

      context 'when track inventory tracking is off' do
        before do
          stock_level.variant.track_inventory = false
          stock_movement.quantity = 1
          stock_movement.save
          stock_level.reload
        end

        it 'does not update count on hand' do
          expect(stock_level.count_on_hand).to eq(10)
        end
      end

      context 'when quantity is negative' do
        before do
          stock_movement.quantity = -1
          stock_movement.save
          stock_level.reload
        end

        it 'decrements the stock level count on hand' do
          expect(stock_level.count_on_hand).to eq(9)
        end
      end

      context 'when quantity is positive' do
        before do
          stock_movement.quantity = 1
          stock_movement.save
          stock_level.reload
        end

        it 'increments the stock level count on hand' do
          expect(stock_level.count_on_hand).to eq(11)
        end
      end

      context 'allocated' do
        it 'raises allocated_count and leaves count_on_hand alone' do
          create(:stock_movement, kind: 'allocated', quantity: 3, stock_level: stock_level)
          stock_level.reload

          expect(stock_level.count_on_hand).to eq(10)
          expect(stock_level.allocated_count).to eq(3)
          expect(stock_level.available_count).to eq(7)
        end
      end

      context 'released' do
        it 'gives the promise back' do
          create(:stock_movement, kind: 'allocated', quantity: 3, stock_level: stock_level)
          create(:stock_movement, kind: 'released', quantity: 2, stock_level: stock_level)
          stock_level.reload

          expect(stock_level.count_on_hand).to eq(10)
          expect(stock_level.allocated_count).to eq(1)
        end

        it 'never drives allocated_count below zero' do
          create(:stock_movement, kind: 'released', quantity: 5, stock_level: stock_level)

          expect(stock_level.reload.allocated_count).to eq(0)
        end
      end

      context 'shipped' do
        it 'takes the units off the shelf and retires their allocation' do
          fulfillment = create(:fulfillment, stock_location: stock_location)
          create(:stock_movement, kind: 'allocated', quantity: 3, stock_level: stock_level, fulfillment: fulfillment)
          create(:stock_movement, kind: 'shipped', quantity: 3, stock_level: stock_level, fulfillment: fulfillment)
          stock_level.reload

          expect(stock_level.count_on_hand).to eq(7)
          expect(stock_level.allocated_count).to eq(0)
        end

        it 'ships unallocated stock without inventing a negative allocation' do
          create(:stock_movement, kind: 'shipped', quantity: 2, stock_level: stock_level)
          stock_level.reload

          expect(stock_level.count_on_hand).to eq(8)
          expect(stock_level.allocated_count).to eq(0)
        end

        # A transfer moves goods nobody promised. Taking somebody else's
        # allocation here would leave the level looking more available than
        # it is.
        it 'leaves other promises alone when the departure has no fulfillment' do
          create(:stock_movement, kind: 'allocated', quantity: 3, stock_level: stock_level)

          create(:stock_movement, kind: 'shipped', quantity: 2, stock_level: stock_level)
          stock_level.reload

          expect(stock_level.count_on_hand).to eq(8)
          expect(stock_level.allocated_count).to eq(3)
          expect(stock_level.available_count).to eq(5)
        end

        # A parcel that physically left has to be recordable whatever the
        # ledger says — the shelf then reads as goods Spree never saw arrive.
        it 'may leave the shelf negative when the caller forced it' do
          stock_level.update_column(:count_on_hand, 0)

          create(:stock_movement, kind: 'shipped', quantity: 1, stock_level: stock_level, force: true)

          expect(stock_level.reload.count_on_hand).to eq(-1)
        end

        # Nobody may send goods a warehouse does not have without saying so —
        # a stock transfer least of all.
        it 'refuses to leave the shelf negative otherwise' do
          stock_level.update_column(:count_on_hand, 0)

          expect {
            create(:stock_movement, kind: 'shipped', quantity: 1, stock_level: stock_level)
          }.to raise_error(ActiveRecord::RecordInvalid)

          expect(stock_level.reload.count_on_hand).to eq(0)
        end

        # An instruction about one write, not a property of the row — so a
        # movement read back later carries no trace of it.
        it 'does not persist the force instruction' do
          movement = create(:stock_movement, kind: 'shipped', quantity: 1, stock_level: stock_level, force: true)

          expect(described_class.find(movement.id).force).to be_nil
        end
      end

      context 'adjusted' do
        it 'applies even when the variant stopped tracking inventory' do
          stock_level.variant.update!(track_inventory: false)
          stock_level.reload.update_column(:count_on_hand, 10)

          create(:stock_movement, kind: 'adjusted', quantity: -4, reason: 'Cycle count', stock_level: stock_level)

          expect(stock_level.reload.count_on_hand).to eq(6)
        end

        it 'refuses to drive the shelf below zero' do
          expect do
            create(:stock_movement, kind: 'adjusted', quantity: -11, reason: 'Cycle count', stock_level: stock_level)
          end.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end
  end
end
