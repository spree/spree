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

      it 'adds the gift on top of the units the shopper chose' do
        Spree::Orders::AddItem.call(order: order, variant: shirt, quantity: 3)
        action.perform(payload)
        line_item = order.line_items.find_by(variant_id: shirt.id)
        expect(line_item.quantity).to eq(5)
        expect(line_item.gifted_quantity).to eq(2)
      end

      it 'adds the gift once' do
        2.times { action.perform(payload) }
        expect(order.line_items.find_by(variant_id: shirt.id).quantity).to eq(2)
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

    it 'takes the gift back after it sells out' do
      promotion.activate(order: cart)
      empty_stock(mug)
      create(:promotion_rule_product, promotion: promotion).products << create(:variant).product
      promotion.reload

      expect(action.revert(order: cart)).to be(true)
      expect(cart.line_items.reload.find_by(variant_id: mug.id)).to be_nil
    end

    it 'leaves the units the shopper chose when it takes the gift back' do
      Spree.cart_add_item_workflow.call(cart: cart, variant: mug, quantity: 1)
      promotion.activate(order: cart)
      expect(cart.line_items.reload.find_by(variant_id: mug.id).quantity).to eq(3)
      create(:promotion_rule_product, promotion: promotion).products << create(:variant).product
      promotion.reload

      expect(action.revert(order: cart)).to be(true)
      line_item = cart.line_items.reload.find_by(variant_id: mug.id)
      expect(line_item.quantity).to eq(1)
      expect(line_item.gifted_quantity).to eq(0)
    end

    it 'takes the gift back from the line holding it when the product sits on two lines' do
      own_line = cart.line_items.create!(variant: mug, quantity: 1, currency: cart.currency)
      gift_line = cart.line_items.create!(variant: mug, quantity: 2, currency: cart.currency)
      create(:line_item_gift, line_item: gift_line, promotion_action: action, quantity: 2)
      comparer = ->(line_item:, **) { Spree::ServiceModule::Result.new(true, line_item == own_line, nil) }
      allow(Spree).to receive(:cart_compare_line_items_service).and_return(comparer)

      expect(action.remove_gifts(cart.reload)).to be(true)
      expect(own_line.reload.quantity).to eq(1)
      expect(Spree::LineItem.exists?(gift_line.id)).to be(false)
    end

    it 'trims the gift when the merchant lowers it, and takes back one the list no longer names' do
      promotion.activate(order: cart)
      action.promotion_action_line_items.first.update!(quantity: 1)

      action.reload.perform(order: cart)
      expect(cart.line_items.reload.find_by(variant_id: mug.id).quantity).to eq(1)

      action.promotion_action_line_items.first.update!(variant: shirt)
      expect(action.reload.remove_gifts(cart)).to be(true)
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

    context 'when the rules name the gift\'s own product' do
      before { create(:promotion_rule_product, promotion: promotion).products << gift.product }

      it 'gives a second one to a shopper who chose one' do
        Spree.cart_add_item_workflow.call(cart: cart, variant: gift, quantity: 1)
        promotion.reload

        expect(promotion.activate(order: cart)).to be(true)
        Spree.cart_recalculate_totals_workflow.call(cart: cart)

        expect(gift_line_item.quantity).to eq(2)
        expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)
        expect(cart.reload.total).to eq(15)
      end

      # The gift stops being free the moment it is the only thing qualifying,
      # and is not re-added, so the shopper can take it out themselves.
      it 'stops paying for the gift when the qualifying line goes' do
        qualifying = create(:variant, price: 20)
        promotion.promotion_rules.first.products << qualifying.product
        Spree.cart_add_item_workflow.call(cart: cart, variant: qualifying, quantity: 1)
        promotion.reload
        promotion.activate(order: cart)
        expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)

        Spree.cart_remove_item_service.call(cart: cart, variant: qualifying, quantity: 1)

        expect(gift_line_item.discounts).to be_empty
        expect(cart.reload.total).to eq(15)
      end
    end

    it 'adds the gift on top of the copies the shopper chose and leaves those paid for' do
      Spree.cart_add_item_workflow.call(cart: cart, variant: gift, quantity: 3)

      expect(promotion.activate(order: cart)).to be(true)
      Spree.cart_recalculate_totals_workflow.call(cart: cart)

      expect(gift_line_item.quantity).to eq(4)
      expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)
      expect(cart.reload.total).to eq(45)
    end

    it "discounts none of the shopper's own units when stock refuses the gift" do
      gift.stock_items.update_all(count_on_hand: 2, backorderable: false)
      Spree.cart_add_item_workflow.call(cart: cart, variant: gift, quantity: 2)

      promotion.activate(order: cart)

      expect(gift_line_item.quantity).to eq(2)
      expect(gift_line_item.gifts).to be_empty
      expect(gift_line_item.discounts).to be_empty
    end

    it "takes the shopper's own units first when they lower the line" do
      Spree.cart_add_item_workflow.call(cart: cart, variant: gift, quantity: 2)
      promotion.activate(order: cart)

      Spree.cart_upsert_items_workflow.call(cart: cart, items: [{ variant_id: gift.id, quantity: 2 }])

      expect(gift_line_item.gifted_quantity).to eq(1)
      expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)
      expect(cart.reload.total).to eq(15)
    end

    # A $20 order is inside a 15..25 range; the $15 gift takes the item total
    # to $35 but does not count toward the rule that gave it.
    it 'keeps the gift free when its price would take the order out of range' do
      Spree::Promotion::Rules::ItemTotal.create!(
        promotion: promotion,
        preferred_operator_min: 'gte', preferred_amount_min: 15,
        preferred_operator_max: 'lte', preferred_amount_max: 25
      )
      qualifying = create(:variant, price: 20)
      Spree.cart_add_item_workflow.call(cart: cart, variant: qualifying, quantity: 1)
      promotion.reload

      expect(promotion.activate(order: cart)).to be(true)
      Spree.cart_recalculate_totals_workflow.call(cart: cart)

      cart.reload
      expect(promotion.eligible?(cart)).to be(true)
      expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)
      expect(cart.item_total).to eq(35)
      expect(cart.total).to eq(20)
    end
  end

  # The gift keeps its price on its line and is paid for by a discount, so
  # without taking it out a spend threshold or a percentage off would count it.
  describe 'counting toward what the shopper spends' do
    let(:cart) { create(:cart) }
    let(:blender) { create(:variant, price: 20) }
    let(:gift) { create(:variant, price: 15) }
    let!(:ten_percent_over_50) do
      automatic_promotion.tap do |spend_promotion|
        spend_over(spend_promotion, 50)
        create(:promotion_action_create_adjustment, promotion: spend_promotion, calculator: build(:flat_percent_item_total_calculator))
      end
    end

    def automatic_promotion
      create(:promotion, kind: :automatic, code: nil, store: cart.store)
    end

    def spend_over(promotion, amount)
      Spree::Promotion::Rules::ItemTotal.create!(promotion: promotion, preferred_operator_min: 'gt', preferred_amount_min: amount)
    end

    def gift_with(promotion, variant = gift)
      create(:promotion_action_create_line_items, promotion: promotion).
        promotion_action_line_items.create!(variant: variant, quantity: 1)
    end

    def gift_promotion_buying(product)
      automatic_promotion.tap do |gift_promotion|
        create(:promotion_rule_product, promotion: gift_promotion).products << product
        gift_with(gift_promotion)
      end
    end

    def add(variant, quantity)
      Spree.cart_add_item_workflow.call(cart: cart, variant: variant, quantity: quantity)
      cart.reload
    end

    def gift_line_item
      cart.line_items.reload.find_by(variant_id: gift.id)
    end

    def discount_from(promotion)
      cart.discounts.reload.where(promotion: promotion).sum(:amount)
    end

    context 'when another promotion gives the gift away' do
      before { gift_promotion_buying(blender.product) }

      it 'does not let the gift lift the order over a threshold' do
        add(blender, 2)

        expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)
        expect(cart.item_total).to eq(55)
        expect(discount_from(ten_percent_over_50)).to eq(0)
        expect(cart.total).to eq(40)
      end

      it 'takes a percentage of the paid goods only' do
        add(blender, 3)

        expect(discount_from(ten_percent_over_50)).to eq(-6)
        expect(cart.total).to eq(54)
      end
    end

    it "does not let another promotion's gift qualify for a promotion naming it" do
      gift_promotion_buying(blender.product)
      second_promotion = automatic_promotion
      create(:promotion_rule_product, promotion: second_promotion).products << gift.product
      gift_with(second_promotion, create(:variant, price: 10))
      add(blender, 1)

      expect(second_promotion.reload.activate(order: cart)).to be(false)
      expect(cart.line_items.reload.map(&:variant_id)).to contain_exactly(blender.id, gift.id)
    end

    it "does not add its gift to a line holding another promotion's gift of the same product" do
      gift_promotion_buying(blender.product)
      second_promotion = automatic_promotion
      gift_with(second_promotion)
      add(blender, 1)

      expect(gift_line_item.quantity).to eq(1)
      expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)
      expect(second_promotion.reload.activate(order: cart)).not_to be(true)
      expect(gift_line_item.quantity).to eq(1)
    end

    it 'counts a copy of the gift the shopper pays for' do
      gift_promotion_buying(create(:product))
      add(blender, 2)
      add(gift, 1)

      expect(discount_from(ten_percent_over_50)).to eq(-5.5)
      expect(cart.total).to eq(49.5)
    end

    it 'counts the copy the shopper chose beside the gift' do
      gift_promotion_buying(blender.product)
      add(blender, 2)
      add(gift, 1)

      expect(gift_line_item.quantity).to eq(2)
      expect(discount_from(ten_percent_over_50)).to eq(-5.5)
      expect(cart.total).to eq(49.5)
    end

    it 'counts the gift until its promotion applies to the cart and discounts it' do
      add(blender, 2)
      add(gift, 1)
      gift_promotion = gift_promotion_buying(blender.product)

      Spree.cart_recalculate_totals_workflow.call(cart: cart)

      expect(discount_from(gift_promotion)).to eq(0)
      expect(discount_from(ten_percent_over_50)).to eq(-5.5)
    end

    context 'when the gift promotion has its own threshold' do
      before do
        gift_promotion = automatic_promotion
        spend_over(gift_promotion, 50)
        gift_with(gift_promotion)
      end

      it 'takes the gift back once the paid goods fall below it' do
        add(blender, 3)
        expect(gift_line_item.discounts.sum(&:amount)).to eq(-15)

        Spree.cart_upsert_items_workflow.call(cart: cart, items: [{ variant_id: blender.id, quantity: 2 }])

        expect(gift_line_item).to be_nil
        expect(cart.reload.total).to eq(40)
      end

      it 'settles beside a second gift promotion with a threshold of its own' do
        second_gift = create(:variant, price: 10)
        second_promotion = automatic_promotion
        spend_over(second_promotion, 50)
        gift_with(second_promotion, second_gift)

        add(blender, 3)

        expect(cart.line_items.map(&:variant_id)).to contain_exactly(blender.id, gift.id, second_gift.id)
        expect(discount_from(ten_percent_over_50)).to eq(-6)
        expect(cart.total).to eq(54)
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
