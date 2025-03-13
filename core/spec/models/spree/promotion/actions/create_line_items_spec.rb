require 'spec_helper'

describe Spree::Promotion::Actions::CreateLineItems, type: :model do
  let(:order) { create(:order) }
  let(:action) { Spree::Promotion::Actions::CreateLineItems.create!(promotion: promotion) }
  let(:promotion) { create(:promotion) }
  let(:shirt) { create(:variant) }
  let(:mug) { create(:variant) }
  let(:payload) { { order: order } }

  def empty_stock(variant)
    variant.stock_items.update_all(backorderable: false)
    variant.stock_items.each(&:reduce_count_on_hand_to_zero)
  end

  context '#perform' do
    before do
      allow(action).to receive_messages promotion: promotion
      action.promotion_action_line_items.create!(
        variant: mug,
        quantity: 1
      )
      action.promotion_action_line_items.create!(
        variant: shirt,
        quantity: 2
      )
    end

    context 'order is eligible' do
      before do
        allow(promotion).to receive_messages eligible: true
      end

      it 'adds line items to order with correct variant and quantity' do
        action.perform(payload)
        expect(order.line_items.count).to eq(2)
        line_item = order.line_items.find_by(variant_id: mug.id)
        expect(line_item).not_to be_nil
        expect(line_item.quantity).to eq(1)
      end

      it 'only adds the delta of quantity to an order' do
        Spree::Cart::AddItem.call(order: order, variant: shirt)
        action.perform(payload)
        line_item = order.line_items.find_by(variant_id: shirt.id)
        expect(line_item).not_to be_nil
        expect(line_item.quantity).to eq(2)
      end

      it "doesn't add if the quantity is greater" do
        Spree::Cart::AddItem.call(order: order, variant: shirt, quantity: 3)
        action.perform(payload)
        line_item = order.line_items.find_by(variant_id: shirt.id)
        expect(line_item).not_to be_nil
        expect(line_item.quantity).to eq(3)
      end

      it "doesn't try to add an item if it's out of stock" do
        empty_stock(mug)
        empty_stock(shirt)

        expect(action.perform(order: order)).to eq(false)
      end
    end
  end

  describe '#item_available?' do
    let(:item_out_of_stock) do
      action.promotion_action_line_items.create!(variant: mug, quantity: 1)
    end

    let(:item_in_stock) do
      action.promotion_action_line_items.create!(variant: shirt, quantity: 1)
    end

    it 'returns false if the item is out of stock' do
      empty_stock(mug)
      expect(action.item_available?(item_out_of_stock)).to be false
    end

    it 'returns true if the item is in stock' do
      expect(action.item_available?(item_in_stock)).to be true
    end
  end

  describe '#handle_promotion_action_line_items' do
    let(:promotion_action_line_items_attributes) do
      {
        '0' => { 'variant_id' => shirt.id, 'quantity' => 1 },
        '1' => { 'variant_id' => mug.id, 'quantity' => 2 }
      }
    end

    before do
      action.promotion_action_line_items_attributes = promotion_action_line_items_attributes
    end

    it 'creates new promotion action line items' do
      expect { action.save! }.to change(action.promotion_action_line_items, :count).by(2)

      expect(action.promotion_action_line_items.find_by(variant_id: shirt.id).quantity).to eq(1)
      expect(action.promotion_action_line_items.find_by(variant_id: mug.id).quantity).to eq(2)
    end

    context 'with existing promotion action line items' do
      before do
        action.save!
        # Change quantity for existing item
        action.promotion_action_line_items_attributes = {
          '0' => { 'variant_id' => shirt.id, 'quantity' => 3 }
        }
      end

      it 'updates existing promotion action line items' do
        expect { action.save! }.not_to change(action.promotion_action_line_items, :count)
        expect(action.promotion_action_line_items.find_by(variant_id: shirt.id).quantity).to eq(3)
        expect(action.promotion_action_line_items.find_by(variant_id: mug.id).quantity).to eq(2)
      end
    end

    context 'with items marked for destruction' do
      before do
        action.save!
        action.promotion_action_line_items_attributes = {
          '0' => { 'id' => action.promotion_action_line_items.find_by(variant_id: shirt.id).id, '_destroy' => '1' }
        }
      end

      it 'removes items marked for destruction' do
        expect { action.save! }.to change(action.promotion_action_line_items, :count).by(-1)
        expect(action.promotion_action_line_items.find_by(variant_id: shirt.id)).to be_nil
        expect(action.promotion_action_line_items.find_by(variant_id: mug.id)).to be_present
      end
    end
  end
end
