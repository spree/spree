require 'spec_helper'

describe Spree::StockMovement, :type => :model do

  describe 'Constants' do

    describe 'MAX_QUANTITY' do
      it 'return 2147483647' do
        expect(Spree::StockMovement::MAX_QUANTITY).to eq(2147483647)
      end
    end

    describe 'MIN_QUANTITY' do
      it 'return -2147483648' do
        expect(Spree::StockMovement::MIN_QUANTITY).to eq(-2147483648)
      end
    end

  end

  describe 'Associations' do

    it { should belong_to(:stock_item).class_name('Spree::StockItem').inverse_of(:stock_movements) }
    it { should belong_to(:originator) }

  end

  describe 'Validations' do

    it { should validate_presence_of(:stock_item) }
    it { should validate_presence_of(:quantity) }
    it do should validate_numericality_of(:quantity).
      is_greater_than_or_equal_to(Spree::StockMovement::MIN_QUANTITY).
      is_less_than_or_equal_to(Spree::StockMovement::MAX_QUANTITY).
      only_integer.allow_nil
    end
  end

  describe 'Callbacks' do
    it { is_expected.to callback(:update_stock_item_quantity).after(:create) }
  end

  describe 'Scope' do
    describe '.recent' do
      it 'should order chronologically by created at' do
        expect(Spree::StockMovement.recent.to_sql).
          to eq Spree::StockMovement.unscoped.order(created_at: :desc).to_sql
      end
    end
  end

  describe 'whitelisted ransackable attributes' do
    it 'returns amount attribute' do
      expect(Spree::StockMovement.whitelisted_ransackable_attributes).to eq(['quantity'])
    end
  end

  describe 'Insatance Methods' do

    let(:stock_location) { create(:stock_location_with_items) }
    let(:stock_item) { stock_location.stock_items.order(:id).first }

    describe '#readonly?' do
      let(:stock_movement) { create(:stock_movement, stock_item: stock_item) }
      it 'should not update a persisted records' do
        expect {
          stock_movement.save
        }.to raise_error(ActiveRecord::ReadOnlyRecord)
      end
    end

    describe '#update_stock_item_quantity' do

      let(:stock_movement) { build(:stock_movement, stock_item: stock_item) }

      context 'when track inventory levels is false' do
        before do
          Spree::Config[:track_inventory_levels] = false
          stock_movement.quantity = 1
          stock_movement.save
          stock_item.reload
        end
        it 'does not update count on hand' do
          expect(stock_item.count_on_hand).to eq(10)
        end
      end

      context 'when track inventory tracking is off' do
        before do
          stock_item.variant.track_inventory = false
          stock_movement.quantity = 1
          stock_movement.save
          stock_item.reload
        end
        it 'does not update count on hand' do
          expect(stock_item.count_on_hand).to eq(10)
        end
      end

      context 'when quantity is negative' do
        before do
          stock_movement.quantity = -1
          stock_movement.save
          stock_item.reload
        end
        it 'should decrement the stock item count on hand' do
          expect(stock_item.count_on_hand).to eq(9)
        end
      end

      context "when quantity is positive" do
        before do
          stock_movement.quantity = 1
          stock_movement.save
          stock_item.reload
        end
        it "should increment the stock item count on hand" do
          expect(stock_item.count_on_hand).to eq(11)
        end
      end
    end
  end
end
