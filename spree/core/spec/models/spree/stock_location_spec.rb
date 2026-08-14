require 'spec_helper'

module Spree
  describe StockLocation, type: :model do
    subject { create(:stock_location_with_items, backorderable_default: true) }

    let(:stock_level) { subject.stock_levels.order(:id).first }
    let(:variant) { stock_level.variant }

    context 'handling the stock items creation after create' do
      let!(:variant) { create(:variant) }

      before do
        Spree::StockLevel.delete_all
        described_class.delete_all
      end

      it 'creates stock_levels for all variants' do
        expect do
          perform_enqueued_jobs { create(:stock_location, propagate_all_variants: true) }
        end.to(
          change { Variant.count }.by(0).and(
            change { described_class.count }.from(0).to(1).and(
              change { StockLevel.count }.from(0).to(2)
            )
          )
        )
      end
    end

    it 'validates uniqueness' do
      described_class.create(name: 'Test')
      expect(described_class.new(name: 'Test')).not_to be_valid
    end

    context 'handling stock items' do
      let!(:variant) { create(:variant) }

      context 'given a variant' do
        subject { described_class.create(name: 'testing', propagate_all_variants: false) }

        context 'set up' do
          it 'creates stock item' do
            expect(subject).to receive(:propagate_variant)
            subject.set_up_stock_level(variant)
          end

          context 'stock item exists' do
            let!(:stock_level) { subject.propagate_variant(variant) }

            it 'returns existing stock item' do
              expect(subject.set_up_stock_level(variant)).to eq(stock_level)
            end
          end
        end

        context 'propagate variants' do
          let(:stock_level) { subject.propagate_variant(variant) }

          it 'creates a new stock item' do
            expect do
              subject.propagate_variant(variant)
            end.to change(StockLevel, :count).by(1)
          end

          context 'passes backorderable default config' do
            context 'true' do
              before { subject.backorderable_default = true }

              it { expect(stock_level.backorderable).to be true }
            end

            context 'false' do
              before { subject.backorderable_default = false }

              it { expect(stock_level.backorderable).to be false }
            end
          end
        end

        context 'propagate all variants' do
          subject { described_class.new(name: 'testing') }

          context 'true' do
            before { subject.propagate_all_variants = true }

            specify do
              expect(subject).to receive(:create_stock_levels).and_call_original
              expect(Spree::StockLocations::StockLevels::CreateJob).to(
                receive(:perform_later).once.with(subject)
              )
              subject.save!
            end
          end

          context 'false' do
            before { subject.propagate_all_variants = false }

            specify do
              expect(subject).not_to receive(:create_stock_levels)
              subject.save!
            end
          end
        end
      end
    end

    it 'finds a stock_level for a variant' do
      stock_level = subject.stock_level(variant)
      expect(stock_level.count_on_hand).to eq 10
    end

    it 'finds a stock_level for a variant by id' do
      stock_level = subject.stock_level(variant.id)
      expect(stock_level.variant).to eq variant
    end

    it 'returns nil when stock_level is not found for variant' do
      variant_id = variant.id + 1000
      stock_level = subject.stock_level(variant_id)
      expect(stock_level).to be_nil
    end

    describe '#stock_level_or_create' do
      context 'without stock item' do
        let!(:variant) { create(:variant) }

        before { variant.stock_levels.delete_all }

        context 'variant instance passed' do
          it 'creates a stock_level if not found for a variant' do
            stock_level = subject.stock_level_or_create(variant)
            expect(stock_level.variant).to eq variant
          end

          it { expect { subject.stock_level_or_create(variant) }.to change(Spree::StockLevel, :count) }
        end

        context 'variant ID passed' do
          it 'creates a stock_level if not found for a variant' do
            stock_level = subject.stock_level_or_create(variant.id)
            expect(stock_level.variant).to eq variant
          end

          it { expect { subject.stock_level_or_create(variant.id) }.to change(Spree::StockLevel, :count) }
        end
      end

      context 'with stock item' do
        let!(:variant) { create(:variant) }
        let!(:stock_level) { create(:stock_level, variant: variant, stock_location: subject) }

        context 'variant instance passed' do
          it { expect { subject.stock_level_or_create(variant) }.not_to change(Spree::StockLevel, :count) }
          it { expect(subject.stock_level_or_create(variant)).to eq(stock_level) }
        end

        context 'variant ID passed' do
          it { expect { subject.stock_level_or_create(variant.id) }.not_to change(Spree::StockLevel, :count) }
          it { expect(subject.stock_level_or_create(variant.id)).to eq(stock_level) }
        end
      end
    end

    it 'finds a count_on_hand for a variant' do
      expect(subject.count_on_hand(variant)).to eq 10
    end

    it 'finds determines if you a variant is backorderable' do
      expect(subject.backorderable?(variant)).to be true
    end

    it 'restocks a variant with a received movement' do
      cause = double
      expect(subject).to receive(:move).with(variant, 5, kind: 'received', cause: cause, persist: true)
      subject.restock(variant, 5, cause)
    end

    # The sign no longer carries the direction — the kind does — so a
    # departure is written positive like every other order-driven kind.
    it 'unstocks a variant with a shipped movement' do
      cause = double
      expect(subject).to receive(:move).with(variant, 5, kind: 'shipped', cause: cause, persist: true)
      subject.unstock(variant, 5, cause)
    end

    it 'allocates a variant to a fulfillment' do
      fulfillment = double
      expect(subject).to receive(:move).with(variant, 2, kind: 'allocated', cause: fulfillment)
      subject.allocate(variant, 2, fulfillment)
    end

    it 'releases a variant from a fulfillment' do
      fulfillment = double
      expect(subject).to receive(:move).with(variant, 2, kind: 'released', cause: fulfillment)
      subject.release(variant, 2, fulfillment)
    end

    it 'adjusts a variant with a reason' do
      expect(subject).to receive(:move).with(variant, -2, kind: 'adjusted', reason: 'Damaged')
      subject.adjust(variant, -2, reason: 'Damaged')
    end

    it 'creates a stock_movement' do
      expect do
        subject.move variant, 5, kind: 'received'
      end.to change { subject.stock_movements.where(stock_level_id: stock_level).count }.by(1)
    end

    describe 'cause keys' do
      let(:order) { create(:order) }
      let(:fulfillment) { create(:fulfillment, order: order, stock_location: subject) }

      it 'carries the fulfillment and its order onto an allocation' do
        subject.allocate(variant, 1, fulfillment)
        movement = subject.stock_movements.last

        expect(movement.kind).to eq('allocated')
        expect(movement.fulfillment).to eq(fulfillment)
        expect(movement.order).to eq(order)
      end

      it 'leaves the cause keys empty for a plain adjustment' do
        subject.adjust(variant, 1, reason: 'Cycle count')
        movement = subject.stock_movements.last

        expect(movement.reason).to eq('Cycle count')
        expect(movement.fulfillment_id).to be_nil
        expect(movement.order_id).to be_nil
      end
    end

    it 'can be deactivated' do
      create(:stock_location, active: true)
      create(:stock_location, active: false)
      expect(described_class.active.count).to eq 1
    end

    it 'ensures only one stock location is default at a time' do
      first = create(:stock_location, active: true, default: true)
      second = create(:stock_location, active: true, default: true)

      expect(first.reload.default).to eq false
      expect(second.reload.default).to eq true

      first.default = true
      first.save!

      expect(first.reload.default).to eq true
      expect(second.reload.default).to eq false
    end

    context 'fill_status' do
      let(:zero_stock_level) { subject.stock_levels.order(:id).second }

      before { allow(zero_stock_level).to receive_messages(backorderable?: true, count_on_hand: 0) }

      it 'all on_hand with no backordered' do
        on_hand, backordered = subject.fill_status(variant, 5)
        expect(on_hand).to eq 5
        expect(backordered).to eq 0
      end

      it 'some on_hand with some backordered' do
        on_hand, backordered = subject.fill_status(variant, 20)
        expect(on_hand).to eq 10
        expect(backordered).to eq 10
      end

      it 'zero on_hand with all backordered' do
        expect(subject).to receive(:stock_level_or_create).with(variant).and_return(zero_stock_level)

        on_hand, backordered = subject.fill_status(variant, 20)
        expect(on_hand).to eq 0
        expect(backordered).to eq 20
      end

      context 'when backordering is not allowed' do
        before do
          allow(stock_level).to receive_messages backorderable?: false
          expect(subject).to receive(:stock_level_or_create).with(variant).and_return(stock_level)
        end

        it 'all on_hand' do
          allow(stock_level).to receive_messages(count_on_hand: 10)

          on_hand, backordered = subject.fill_status(variant, 5)
          expect(on_hand).to eq 5
          expect(backordered).to eq 0
        end

        it 'some on_hand' do
          allow(stock_level).to receive_messages(count_on_hand: 10)

          on_hand, backordered = subject.fill_status(variant, 20)
          expect(on_hand).to eq 10
          expect(backordered).to eq 0
        end

        it 'zero on_hand' do
          allow(stock_level).to receive_messages(count_on_hand: 0)

          on_hand, backordered = subject.fill_status(variant, 20)
          expect(on_hand).to eq 0
          expect(backordered).to eq 0
        end
      end

      context 'without stock_levels' do
        subject { create(:stock_location) }

        let(:variant) { create(:base_variant) }

        it 'zero on_hand and one backordered' do
          subject
          variant.stock_levels.delete_all
          on_hand, backordered = subject.fill_status(variant, 1)
          expect(on_hand).to eq 0
          expect(backordered).to eq 1
        end
      end
    end

    context '#state_text' do
      context 'state is blank' do
        subject { described_class.create(name: 'testing', state_code: nil, state_name: 'virginia') }

        specify { expect(subject.state_text).to eq('virginia') }
      end

      context 'a state code is present' do
        subject { described_class.create(name: 'testing', country_code: 'US', state_code: 'VA', state_name: nil) }

        specify { expect(subject.state_text).to eq('VA') }
      end
    end

    describe '#conditionally_touch_records' do
      let(:item) { subject.items.last }
      let(:variant) { subject.variants.last }

      context 'active has changed' do
        it { expect { subject.update(active: false).to change(variant, :updated_at) } }
        it { expect { subject.update(active: false).to change(item, :updated_at) } }
      end

      context 'active has not changed' do
        it { expect { subject.update(name: 'my other warehouse').to change(variant, :updated_at) } }
      end
    end

    describe '#address' do
      it 'returns Spree::Address instance' do
        expect(subject.address).to be_an_instance_of(Spree::Address)
      end
    end

    describe '#display_name' do
      it 'returns the name' do
        expect(subject.display_name).to eq(subject.name)
      end

      context 'with admin name set' do
        let(:admin_name) { 'admin name' }

        before { subject.admin_name = admin_name }

        it 'returns the admin name' do
          expect(subject.display_name).to eq("#{admin_name} / #{subject.name}")
        end
      end
    end

    describe '#country_name' do
      it 'returns the country name' do
        expect(subject.country_name).to eq(subject.country.name)
      end
    end

    context 'when country is nil' do
      subject { build(:stock_location, country: nil, state: nil) }

      it { expect(subject.country_name).to be_nil }
      it { expect(subject.country_code).to be_nil }
      it { expect(subject.country_iso3).to be_nil }
      it { expect(subject.country_iso_name).to be_nil }
    end

    describe 'KINDS / PICKUP_STOCK_POLICIES constants' do
      it 'lists the built-in kinds' do
        expect(StockLocation::KINDS).to eq(%w[warehouse store fulfillment_center])
      end

      it 'lists the pickup stock policies' do
        expect(StockLocation::PICKUP_STOCK_POLICIES).to eq(%w[local any])
      end
    end

    describe 'pickup defaults' do
      subject { build(:stock_location) }

      it 'defaults kind to warehouse' do
        expect(subject.kind).to eq('warehouse')
      end

      it 'defaults pickup_enabled to false' do
        expect(subject.pickup_enabled).to be false
      end

      it 'defaults pickup_stock_policy to local' do
        expect(subject.pickup_stock_policy).to eq('local')
      end
    end

    describe 'validations' do
      it 'requires a kind' do
        sl = build(:stock_location, kind: nil)
        expect(sl).not_to be_valid
        expect(sl.errors[:kind]).to be_present
      end

      it 'rejects an invalid pickup_stock_policy' do
        sl = build(:stock_location, pickup_stock_policy: 'bogus')
        expect(sl).not_to be_valid
        expect(sl.errors[:pickup_stock_policy]).to be_present
      end

      it 'accepts a valid pickup_stock_policy' do
        expect(build(:stock_location, pickup_stock_policy: 'any')).to be_valid
      end

      it 'rejects a negative pickup_ready_in_minutes' do
        sl = build(:stock_location, pickup_ready_in_minutes: -1)
        expect(sl).not_to be_valid
        expect(sl.errors[:pickup_ready_in_minutes]).to be_present
      end

      it 'allows nil pickup_ready_in_minutes' do
        expect(build(:stock_location, pickup_ready_in_minutes: nil)).to be_valid
      end
    end

    describe '.pickup_enabled scope' do
      let!(:enabled) { create(:stock_location, pickup_enabled: true) }
      let!(:disabled) { create(:stock_location, pickup_enabled: false) }

      it 'returns only locations with pickup enabled' do
        expect(StockLocation.pickup_enabled).to include(enabled)
        expect(StockLocation.pickup_enabled).not_to include(disabled)
      end
    end

    describe '#country_code=' do
      let(:country) { Spree::Country.by_iso('US') }
      let(:stock_location) { build(:stock_location, country: nil, state: nil) }

      it 'resolves the country from an ISO code on validation' do
        stock_location.country_code = country.iso
        stock_location.valid?
        expect(stock_location.country).to eq(country)
      end

      it 'clears the country when blank' do
        stock_location.country_code = country.iso
        stock_location.country_code = ''
        stock_location.valid?
        expect(stock_location.country).to be_nil
      end
    end

    describe '#state_code=' do
      let(:country) { Spree::Country.by_iso('US') }
      let!(:state) { Spree::State.resolve(country.iso, 'NY') }
      let(:stock_location) { build(:stock_location, country: country, state: nil) }

      it 'resolves the state from an abbreviation scoped to the country' do
        stock_location.state_code = 'NY'
        stock_location.valid?
        expect(stock_location.state).to eq(state)
      end

      it 'leaves state nil when no matching abbreviation exists for the country' do
        stock_location.state_code = 'ZZ'
        stock_location.valid?
        expect(stock_location.state).to be_nil
      end

      it 'resolves nothing without a country — a subdivision code is only unique within one' do
        stock_location.country_code = nil
        stock_location.state_code = 'NY'
        stock_location.valid?
        expect(stock_location.state).to be_nil
      end
    end
  end
end
