require 'spec_helper'

module Spree
  describe StockLocation, type: :model do
    subject { create(:stock_location_with_items, backorderable_default: true) }

    let(:stock_item) { subject.stock_items.order(:id).first }
    let(:variant) { stock_item.variant }

    context 'handling the stock items creation after create' do
      let!(:variant) { create(:variant) }

      before { described_class.destroy_all }

      it 'creates stock_items for all variants' do
        expect do
          create(:stock_location, propagate_all_variants: true)
        end.to(
          change { Variant.count }.by(0).and(
            change { described_class.count }.from(0).to(1).and(
              change { StockItem.count }.from(0).to(2)
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
            subject.set_up_stock_item(variant)
          end

          context 'stock item exists' do
            let!(:stock_item) { subject.propagate_variant(variant) }

            it 'returns existing stock item' do
              expect(subject.set_up_stock_item(variant)).to eq(stock_item)
            end
          end
        end

        context 'propagate variants' do
          let(:stock_item) { subject.propagate_variant(variant) }

          it 'creates a new stock item' do
            expect do
              subject.propagate_variant(variant)
            end.to change(StockItem, :count).by(1)
          end

          context 'passes backorderable default config' do
            context 'true' do
              before { subject.backorderable_default = true }

              it { expect(stock_item.backorderable).to be true }
            end

            context 'false' do
              before { subject.backorderable_default = false }

              it { expect(stock_item.backorderable).to be false }
            end
          end
        end

        context 'propagate all variants' do
          subject { described_class.new(name: 'testing') }

          context 'true' do
            before { subject.propagate_all_variants = true }

            specify do
              expect(subject).to receive(:create_stock_items).and_call_original
              expect(Spree::StockLocations::StockItems::CreateJob).to(
                receive(:perform_later).once.with(subject)
              )
              subject.save!
            end
          end

          context 'false' do
            before { subject.propagate_all_variants = false }

            specify do
              expect(subject).not_to receive(:create_stock_items)
              subject.save!
            end
          end
        end
      end
    end

    it 'finds a stock_item for a variant' do
      stock_item = subject.stock_item(variant)
      expect(stock_item.count_on_hand).to eq 10
    end

    it 'finds a stock_item for a variant by id' do
      stock_item = subject.stock_item(variant.id)
      expect(stock_item.variant).to eq variant
    end

    it 'returns nil when stock_item is not found for variant' do
      variant_id = variant.id + 1000
      stock_item = subject.stock_item(variant_id)
      expect(stock_item).to be_nil
    end

    describe '#stock_item_or_create' do
      context 'without stock item' do
        let!(:variant) { create(:variant) }

        before { variant.stock_items.destroy_all }

        context 'variant instance passed' do
          it 'creates a stock_item if not found for a variant' do
            stock_item = subject.stock_item_or_create(variant)
            expect(stock_item.variant).to eq variant
          end

          it { expect { subject.stock_item_or_create(variant) }.to change(Spree::StockItem, :count) }
        end

        context 'variant ID passed' do
          it 'creates a stock_item if not found for a variant' do
            stock_item = subject.stock_item_or_create(variant.id)
            expect(stock_item.variant).to eq variant
          end

          it { expect { subject.stock_item_or_create(variant.id) }.to change(Spree::StockItem, :count) }
        end
      end

      context 'with stock item' do
        let!(:variant) { create(:variant) }
        let!(:stock_item) { create(:stock_item, variant: variant, stock_location: subject) }

        context 'variant instance passed' do
          it { expect { subject.stock_item_or_create(variant) }.not_to change(Spree::StockItem, :count) }
          it { expect(subject.stock_item_or_create(variant)).to eq(stock_item) }
        end

        context 'variant ID passed' do
          it { expect { subject.stock_item_or_create(variant.id) }.not_to change(Spree::StockItem, :count) }
          it { expect(subject.stock_item_or_create(variant.id)).to eq(stock_item) }
        end
      end
    end

    it 'finds a count_on_hand for a variant' do
      expect(subject.count_on_hand(variant)).to eq 10
    end

    it 'finds determines if you a variant is backorderable' do
      expect(subject.backorderable?(variant)).to be true
    end

    it 'restocks a variant with a positive stock movement' do
      originator = double
      expect(subject).to receive(:move).with(variant, 5, originator)
      subject.restock(variant, 5, originator)
    end

    it 'unstocks a variant with a negative stock movement' do
      originator = double
      expect(subject).to receive(:move).with(variant, -5, originator)
      subject.unstock(variant, 5, originator)
    end

    it 'creates a stock_movement' do
      expect do
        subject.move variant, 5
      end.to change { subject.stock_movements.where(stock_item_id: stock_item).count }.by(1)
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
      let(:zero_stock_item) { subject.stock_items.order(:id).second }

      before { allow(zero_stock_item).to receive_messages(backorderable?: true, count_on_hand: 0) }

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
        expect(subject).to receive(:stock_item_or_create).with(variant).and_return(zero_stock_item)

        on_hand, backordered = subject.fill_status(variant, 20)
        expect(on_hand).to eq 0
        expect(backordered).to eq 20
      end

      context 'when backordering is not allowed' do
        before do
          allow(stock_item).to receive_messages backorderable?: false
          expect(subject).to receive(:stock_item_or_create).with(variant).and_return(stock_item)
        end

        it 'all on_hand' do
          allow(stock_item).to receive_messages(count_on_hand: 10)

          on_hand, backordered = subject.fill_status(variant, 5)
          expect(on_hand).to eq 5
          expect(backordered).to eq 0
        end

        it 'some on_hand' do
          allow(stock_item).to receive_messages(count_on_hand: 10)

          on_hand, backordered = subject.fill_status(variant, 20)
          expect(on_hand).to eq 10
          expect(backordered).to eq 0
        end

        it 'zero on_hand' do
          allow(stock_item).to receive_messages(count_on_hand: 0)

          on_hand, backordered = subject.fill_status(variant, 20)
          expect(on_hand).to eq 0
          expect(backordered).to eq 0
        end
      end

      context 'without stock_items' do
        subject { create(:stock_location) }

        let(:variant) { create(:base_variant) }

        it 'zero on_hand and one backordered' do
          subject
          variant.stock_items.destroy_all
          on_hand, backordered = subject.fill_status(variant, 1)
          expect(on_hand).to eq 0
          expect(backordered).to eq 1
        end
      end
    end

    context '#state_text' do
      context 'state is blank' do
        subject { described_class.create(name: 'testing', state: nil, state_name: 'virginia') }

        specify { expect(subject.state_text).to eq('virginia') }
      end

      context 'both name and abbr is present' do
        subject { described_class.create(name: 'testing', state: state, state_name: nil) }

        let(:state) { create(:state, name: 'virginia', abbr: 'va') }

        specify { expect(subject.state_text).to eq(state.abbr) }
      end

      context 'only name is present' do
        subject { described_class.create(name: 'testing', state: state, state_name: nil) }

        let(:state) { create(:state, name: 'virginia', abbr: nil) }

        specify { expect(subject.state_text).to eq(state.name) }
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
  end
end
