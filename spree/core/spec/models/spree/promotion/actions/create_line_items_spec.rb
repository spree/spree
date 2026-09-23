require 'spec_helper'

describe Spree::Promotion::Actions::CreateLineItems, type: :model do
  let(:order) { create(:order) }
  let(:action) { Spree::Promotion::Actions::CreateLineItems.create!(promotion: promotion) }
  let(:promotion) { create(:promotion) }
  let(:shirt) { create(:variant) }
  let(:mug) { create(:variant) }
  let(:payload) { { order: order } }

  def empty_stock(variant)
    variant.stock_levels.update_all(backorderable: false)
    variant.stock_levels.each(&:reduce_count_on_hand_to_zero)
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
        Spree::Orders::AddItem.call(order: order, variant: shirt)
        action.perform(payload)
        line_item = order.line_items.find_by(variant_id: shirt.id)
        expect(line_item).not_to be_nil
        expect(line_item.quantity).to eq(2)
      end

      it "doesn't add if the quantity is greater" do
        Spree::Orders::AddItem.call(order: order, variant: shirt, quantity: 3)
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

  context 'when the promotable is a cart' do
    let(:cart) { create(:cart) }

    before do
      allow(action).to receive_messages promotion: promotion
      action.promotion_action_line_items.create!(variant: mug, quantity: 2)
    end

    it 'adds the gift to the cart' do
      expect(action.perform(order: cart)).to be(true)
      expect(cart.line_items.reload.find_by(variant_id: mug.id).quantity).to eq(2)
    end

    it 'takes the gift back when the promotion stops applying' do
      # Through `activate` rather than `perform`, because it is `activate` that
      # joins the promotion to the cart — which is what marks the gift as ours.
      promotion.activate(order: cart)
      # Genuinely ineligible rather than stubbed: removing the gift recalculates
      # the cart, and the handler reloads the promotion from the database.
      create(:promotion_rule_product, promotion: promotion).products << create(:variant).product
      promotion.reload

      expect(action.revert(order: cart)).to be(true)
      expect(cart.line_items.reload.find_by(variant_id: mug.id)).to be_nil
    end

    it 'leaves the variant alone on a cart the promotion never applied to' do
      Spree.cart_add_item_workflow.call(cart: cart, variant: mug, quantity: 2)
      allow(promotion).to receive(:eligible?).and_return(false)

      expect(action.revert(order: cart)).to be_nil
      expect(cart.line_items.reload.find_by(variant_id: mug.id).quantity).to eq(2)
    end
  end

  describe 'pricing the gift' do
    let(:cart) { create(:cart) }
    let(:gift) { create(:variant, price: 15) }

    before { action.promotion_action_line_items.create!(variant: gift, quantity: 1) }

    def gift_line_item
      cart.line_items.reload.find_by(variant_id: gift.id)
    end

    it 'discounts the gift it adds down to nothing' do
      promotion.activate(order: cart)
      Spree.cart_recalculate_totals_workflow.call(cart: cart)

      expect(gift_line_item.quantity).to eq(1)
      expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)

      cart.reload
      expect(cart.item_total).to eq(15)
      expect(cart.discount_total).to eq(-15)
      expect(cart.total).to eq(0)
    end

    it 'makes only Y free on a "buy X, get Y free" promotion' do
      qualifying = create(:variant, price: 20)
      create(:promotion_rule_product, promotion: promotion).products << qualifying.product
      Spree.cart_add_item_workflow.call(cart: cart, variant: qualifying, quantity: 1)

      promotion.activate(order: cart)
      Spree.cart_recalculate_totals_workflow.call(cart: cart)

      expect(gift_line_item.quantity).to eq(1)
      expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)
      expect(cart.line_items.reload.find_by(variant_id: qualifying.id).discounts).to be_empty

      cart.reload
      expect(cart.item_total).to eq(35)
      expect(cart.discount_total).to eq(-15)
      expect(cart.total).to eq(20)
    end

    it "discounts the shopper's own copy instead of adding a second one" do
      Spree.cart_add_item_workflow.call(cart: cart, variant: gift, quantity: 1)

      expect(promotion.activate(order: cart)).to be(true)
      expect(gift_line_item.quantity).to eq(1)
      expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)
    end

    it 'leaves units beyond the gifted quantity paid for' do
      Spree.cart_add_item_workflow.call(cart: cart, variant: gift, quantity: 3)

      promotion.activate(order: cart)

      expect(gift_line_item.quantity).to eq(3)
      expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)
    end

    # A $20 order is inside a 15..25 range until the $15 gift lands and takes it
    # to $35. The rule is still enforced — the promotion is ineligible and the
    # gift earns no discount — but the promotion joins the order on the strength
    # of the add alone, which is the only thing that lets `revert` reach the
    # gift. This configuration leaves a paid-for gift in the cart; it does so on
    # 5.6 too, and closing it needs a gift to stop counting toward the rule that
    # gave it.
    it 'joins the promotion, unfreed, when the gift takes the order out of range' do
      Spree::Promotion::Rules::ItemTotal.create!(
        promotion: promotion,
        preferred_operator_min: 'gte', preferred_amount_min: 15,
        preferred_operator_max: 'lte', preferred_amount_max: 25
      )
      qualifying = create(:variant, price: 20)
      Spree.cart_add_item_workflow.call(cart: cart, variant: qualifying, quantity: 1)
      promotion.reload

      expect(promotion.activate(order: cart)).to be(true)
      expect(cart.promotions.reload).to include(promotion)

      cart.reload
      expect(promotion.eligible?(cart)).to be(false)
      expect(gift_line_item.discounts).to be_empty
      expect(cart.item_total).to eq(35)
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
        # Submit the full desired set — both rows present, shirt's quantity bumped.
        action.promotion_action_line_items_attributes = {
          '0' => { 'variant_id' => shirt.id, 'quantity' => 3 },
          '1' => { 'variant_id' => mug.id, 'quantity' => 2 }
        }
      end

      it 'updates existing promotion action line items in place' do
        expect { action.save! }.not_to change(action.promotion_action_line_items, :count)
        expect(action.promotion_action_line_items.find_by(variant_id: shirt.id).quantity).to eq(3)
        expect(action.promotion_action_line_items.find_by(variant_id: mug.id).quantity).to eq(2)
      end
    end

    context 'with rows omitted from the desired set' do
      before do
        action.save!
        # Omitting `mug` from the submitted set deletes it; the list is
        # the desired state, not a diff. Mirrors the API v3 flat payload.
        action.promotion_action_line_items_attributes = {
          '0' => { 'variant_id' => shirt.id, 'quantity' => 1 }
        }
      end

      it 'removes the omitted rows' do
        expect { action.save! }.to change(action.promotion_action_line_items, :count).by(-1)
        expect(action.promotion_action_line_items.find_by(variant_id: shirt.id)).to be_present
        expect(action.promotion_action_line_items.find_by(variant_id: mug.id)).to be_nil
      end
    end
  end

  # A gift the promotion's store cannot sell is dropped rather than written
  # as a row with no variant.
  context 'when given a variant from another store' do
    let(:foreign_variant) { create(:product, store: create(:store)).default_variant }

    it 'drops it' do
      action.promotion_action_line_items_attributes = [
        { 'variant_id' => foreign_variant.prefixed_id, 'quantity' => 1 }
      ]
      action.save!

      expect(action.promotion_action_line_items.reload).to be_empty
    end
  end
end
