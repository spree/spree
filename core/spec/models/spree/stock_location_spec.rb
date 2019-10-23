require 'spec_helper'

module Spree
  describe StockLocation, type: :model do
    subject { create(:stock_location_with_items, backorderable_default: true) }

    let(:stock_item) { subject.stock_items.order(:id).first }
    let(:variant) { stock_item.variant }

    it 'creates stock_items for all variants' do
      expect(subject.stock_items.count).to eq Variant.count
    end

    it 'validates uniqueness' do
      StockLocation.create(name: 'Test')
      expect(StockLocation.new(name: 'Test')).not_to be_valid
    end

    context 'handling stock items' do
      let!(:variant) { create(:variant) }

      context 'given a variant' do
        subject { StockLocation.create(name: 'testing', propagate_all_variants: false) }

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
          subject { StockLocation.new(name: 'testing') }

          context 'true' do
            before { subject.propagate_all_variants = true }

            specify do
              expect(subject).to receive(:propagate_variant).at_least(:once)
              subject.save!
            end
          end

          context 'false' do
            before { subject.propagate_all_variants = false }

            specify do
              expect(subject).not_to receive(:propagate_variant)
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
      stock_item = subject.stock_item(100)
      expect(stock_item).to be_nil
    end

    describe '#stock_item_or_create' do
      before do
        variant = create(:variant)
        variant.stock_items.destroy_all
        variant.save
      end

      it 'creates a stock_item if not found for a variant' do
        stock_item = subject.stock_item_or_create(variant)
        expect(stock_item.variant).to eq variant
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
      expect(Spree::StockLocation.active.count).to eq 1
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
        zero_stock_item = mock_model(StockItem,
                                     count_on_hand: 0,
                                     backorderable?: true)
        expect(subject).to receive(:stock_item).with(variant).and_return(zero_stock_item)

        on_hand, backordered = subject.fill_status(variant, 20)
        expect(on_hand).to eq 0
        expect(backordered).to eq 20
      end

      context 'when backordering is not allowed' do
        before do
          @stock_item = mock_model(StockItem, backorderable?: false)
          expect(subject).to receive(:stock_item).with(variant).and_return(@stock_item)
        end

        it 'all on_hand' do
          allow(@stock_item).to receive_messages(count_on_hand: 10)

          on_hand, backordered = subject.fill_status(variant, 5)
          expect(on_hand).to eq 5
          expect(backordered).to eq 0
        end

        it 'some on_hand' do
          allow(@stock_item).to receive_messages(count_on_hand: 10)

          on_hand, backordered = subject.fill_status(variant, 20)
          expect(on_hand).to eq 10
          expect(backordered).to eq 0
        end

        it 'zero on_hand' do
          allow(@stock_item).to receive_messages(count_on_hand: 0)

          on_hand, backordered = subject.fill_status(variant, 20)
          expect(on_hand).to eq 0
          expect(backordered).to eq 0
        end
      end

      context 'without stock_items' do
        subject { create(:stock_location) }

        let(:variant) { create(:base_variant) }

        it 'zero on_hand and backordered' do
          subject
          variant.stock_items.destroy_all
          on_hand, backordered = subject.fill_status(variant, 1)
          expect(on_hand).to eq 0
          expect(backordered).to eq 0
        end
      end
    end

    context '#state_text' do
      context 'state is blank' do
        subject { StockLocation.create(name: 'testing', state: nil, state_name: 'virginia') }

        specify { expect(subject.state_text).to eq('virginia') }
      end

      context 'both name and abbr is present' do
        subject { StockLocation.create(name: 'testing', state: state, state_name: nil) }

        let(:state) { stub_model(Spree::State, name: 'virginia', abbr: 'va') }

        specify { expect(subject.state_text).to eq('va') }
      end

      context 'only name is present' do
        subject { StockLocation.create(name: 'testing', state: state, state_name: nil) }

        let(:state) { stub_model(Spree::State, name: 'virginia', abbr: nil) }

        specify { expect(subject.state_text).to eq('virginia') }
      end
    end
  end
end
