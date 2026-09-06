require 'spec_helper'

module Spree
  # The marketplace half of completion: a basket holding several sellers' goods
  # becomes one order per seller, under a group that holds the single payment.
  describe Carts::Complete, 'splitting by seller' do
    let(:store) { @default_store }
    let(:seller) { create(:seller, :approved, store: store, name: 'Sparks Audio') }
    let(:other_seller) { create(:seller, :approved, store: store, name: 'Quill Books') }

    # A cart of three items, whose sellers the caller decides.
    def cart_for(*sellers)
      cart = create(:cart_ready_for_delivery, store: store, line_items_count: sellers.size)
      cart.line_items.reload.each_with_index do |line_item, index|
        assigned = sellers[index]
        line_item.variant.update!(seller: assigned)
        line_item.update_columns(seller_id: assigned&.id)
      end
      cart.reload.recalculate_totals!
      create(:payment, cart: cart, order: nil, payment_method: Spree::PaymentMethod.first, amount: cart.reload.total)
      cart.reload
    end

    describe 'the gate' do
      it 'leaves an all-first-party cart as a bare order' do
        result = described_class.call(cart: cart_for(nil, nil))

        expect(result).to be_success
        expect(result.value).to be_a(Spree::Order)
        expect(result.value.order_group).to be_nil
        expect(Spree::OrderGroup.count).to eq(0)
      end

      it 'leaves a single-seller cart as a bare order carrying the seller' do
        result = described_class.call(cart: cart_for(seller, seller))

        expect(result.value).to be_a(Spree::Order)
        expect(Spree::OrderGroup.count).to eq(0)
        expect(result.value.line_items.map(&:seller_id).uniq).to eq([seller.id])
      end

      # Nothing to divide, but the sale is still that seller's — and their own
      # order list reads the column, not the line items.
      it 'stamps a single-seller order with its seller' do
        result = described_class.call(cart: cart_for(seller, seller))

        expect(result.value.seller).to eq(seller)
        expect(seller.orders).to include(result.value)
      end

      it 'leaves an all-first-party order with no seller' do
        result = described_class.call(cart: cart_for(nil, nil))

        expect(result.value.seller_id).to be_nil
      end

      it 'splits a cart holding two sellers' do
        result = described_class.call(cart: cart_for(seller, other_seller))

        expect(result).to be_success
        expect(result.value).to be_a(Spree::OrderGroup)
        expect(result.value.orders.count).to eq(2)
      end

      # The mixed basket: the operator's own goods bought alongside a seller's.
      it 'splits first-party items into their own order' do
        result = described_class.call(cart: cart_for(nil, seller))
        group = result.value

        expect(group.orders.count).to eq(2)
        expect(group.orders.map(&:seller_id)).to match_array([nil, seller.id])
        expect(group).to be_includes_first_party
      end

      it 'splits a basket of first-party plus two sellers three ways' do
        result = described_class.call(cart: cart_for(nil, seller, other_seller))
        group = result.value

        expect(group.orders.count).to eq(3)
        expect(group.orders.map(&:seller_id)).to match_array([nil, seller.id, other_seller.id])
      end
    end

    describe 'what each child order holds' do
      let(:cart) { cart_for(nil, seller, other_seller) }
      let(:group) { described_class.call(cart: cart).value }

      it 'gives every child only its own seller’s items' do
        group.orders.each do |order|
          expect(order.line_items.map(&:seller_id).uniq).to eq([order.seller_id])
          expect(order.line_items).to be_present
        end
      end

      it 'accounts for every line item exactly once' do
        moved = group.orders.flat_map { |order| order.line_items.map(&:id) }

        expect(moved.size).to eq(cart.line_items.count)
        expect(moved.uniq.size).to eq(moved.size)
      end

      # The buyer's reference and the paperwork behind it have to travel
      # together: the reference on every order with the document on only one
      # is the reconciliation problem the field exists to solve.
      context 'when the buyer supplied a purchase order' do
        before do
          cart.update!(po_number: 'PO-4471')
          cart.po_document.attach(
            io: StringIO.new('%PDF-1.4 purchase order'),
            filename: 'po.pdf',
            content_type: 'application/pdf'
          )
        end

        it 'carries the reference and the document onto every child order' do
          group.orders.each do |order|
            expect(order.po_number).to eq('PO-4471')
            expect(order.po_document).to be_attached
          end
        end

        it 'shares one blob rather than duplicating the upload' do
          blob_ids = group.orders.map { |order| order.po_document.blob_id }

          expect(blob_ids.uniq.size).to eq(1)
        end
      end

      it 'computes each child’s totals from its own rows' do
        group.orders.each do |order|
          expect(order.total).to be > 0
          expect(order.item_total).to eq(order.line_items.sum(&:amount))
        end
      end

      it 'places every child' do
        expect(group.orders.map(&:status).uniq).to eq(['placed'])
      end

      it 'numbers the children off the group' do
        expect(group.orders.map(&:number)).to match_array(
          [1, 2, 3].map { |index| "#{group.number}-#{index}" }
        )
      end

      it 'gives each child its own addresses rather than sharing rows' do
        address_ids = group.orders.map(&:ship_address_id)

        expect(address_ids.compact.uniq.size).to eq(address_ids.size)
      end
    end

    # The hardest case: the cart packed everything into one parcel, so the
    # split has to divide the parcel itself — and the delivery the customer was
    # quoted for it, which must not be charged twice.
    describe 'a parcel holding several sellers’ goods' do
      let(:cart) { cart_for(nil, seller, seller) }
      let(:group) { described_class.call(cart: cart).value }

      it 'gives each child its own parcel' do
        expect(cart.fulfillments.count).to eq(1)
        expect(group.orders.map { |order| order.fulfillments.count }).to all(eq(1))
      end

      it 'divides the delivery charge rather than duplicating it' do
        expect(group.orders.sum(&:delivery_total)).to eq(cart.reload.delivery_total)
      end

      it 'keeps the customer’s total exactly what they paid' do
        expect(group.total).to eq(cart.reload.total)
        expect(group.total).to eq(group.payments.sum(:amount))
      end

      it 'carries the chosen delivery rate onto both parcels' do
        rates = group.orders.flat_map { |order| order.fulfillments.map(&:selected_delivery_rate) }

        expect(rates).to all(be_present)
      end

      # Scoped to the orders' own rows rather than the whole table: completion
      # leaves the cart's fulfillment items where they are, as it does its line
      # items, and those still name the order they were copied to.
      it 'leaves every moved row on the order that owns it' do
        group.orders.each do |order|
          order.fulfillments.each do |fulfillment|
            expect(fulfillment.fulfillment_items.map(&:order_id).uniq).to eq([order.id])
          end
        end
      end

      it 'leaves no line item stranded between owners' do
        expect(Spree::LineItem.where(order_id: nil, cart_id: nil)).to be_empty
      end

      # A fulfillment restates its cost from its selected rate whenever its
      # amounts refresh, so a rate left at the undivided figure would quietly
      # restore the full delivery charge on both halves.
      it 'writes the divided cost down onto the rate as well' do
        group.orders.each do |order|
          order.fulfillments.each do |fulfillment|
            expect(fulfillment.selected_delivery_rate.cost).to eq(fulfillment.cost)
          end
        end
      end

      # The delivery charge is divided between the two halves, so the tax
      # charged on it has to be divided the same way. Left whole, the half that
      # kept the original parcel is taxed on delivery it no longer provides and
      # the sibling ships with none at all.
      context 'when the delivery was taxed' do
        let!(:tax_category) { create(:tax_category, store: store, is_default: true) }
        let!(:tax_rate) do
          create(:tax_rate, store: store, country_code: cart.tax_country&.iso, amount: 0.2,
                            included_in_price: false, tax_category: tax_category)
        end

        let(:cart) do
          built = cart_for(nil, seller, seller)
          built.reload.recalculate_totals!
          built.payments.each { |payment| payment.update!(amount: built.reload.total) }
          built.reload
        end

        # The rate has to exist before the cart is costed, and the cart has to
        # exist before the rate can read its country — so the rate is written
        # once the cart is built, and the cart re-costed against it.
        before do
          tax_rate
          cart.reload.recalculate_totals!
          cart.payments.each { |payment| payment.update!(amount: cart.reload.total) }
        end

        it 'taxes the delivery in the first place' do
          expect(cart.tax_lines.where.not(fulfillment_id: nil).sum(:amount)).to be > 0
        end

        it 'divides the delivery tax rather than charging it on both halves' do
          charged = cart.tax_lines.where.not(fulfillment_id: nil).sum(:amount)
          delivery_tax = group.orders.sum do |order|
            order.tax_lines.where.not(fulfillment_id: nil).sum(:amount)
          end

          expect(delivery_tax).to eq(charged)
        end

        it 'leaves each parcel’s tax on the order that ships it' do
          group.orders.each do |order|
            order.tax_lines.where.not(fulfillment_id: nil).each do |tax_line|
              expect(order.fulfillments.ids).to include(tax_line.fulfillment_id)
            end
          end
        end
      end

      it 'survives a later amounts refresh without doubling the delivery charge' do
        before_total = group.orders.sum(&:delivery_total)
        group.orders.each { |order| order.fulfillments.each(&:update_amounts) }

        expect(group.orders.map(&:reload).sum(&:delivery_total)).to eq(before_total)
      end

      # Reservations are released by order, so a line item's hold has to travel
      # with it — otherwise one child releases everyone's and the siblings hold
      # stock until it expires.
      it 'moves each line item’s stock reservation to the order that keeps it' do
        group.orders.each do |order|
          reserved_line_item_ids = Spree::StockReservation.where(order_id: order.id).pluck(:line_item_id).compact

          expect(reserved_line_item_ids - order.line_items.ids).to be_empty
        end
      end
    end

    # The children are still drafts when they are re-summed, so nothing may
    # re-derive their money: the promotion adjuster would delete the discounts
    # just moved onto them and re-test one seller's subset against a threshold
    # the whole basket met, and the tax provider would re-estimate from today's
    # rates. The customer has already paid the answer the checkout gave.
    describe 'money the checkout already settled' do
      let(:promotion) do
        create(:promotion, :with_order_adjustment, store: store,
                                                   weighted_order_adjustment_amount: 6, code: 'SAVE6')
      end

      let(:cart) do
        promotion
        built = cart_for(nil, seller)
        built.coupon_code = 'SAVE6'
        Spree::PromotionHandler::Coupon.new(built).apply
        built.reload.recalculate_totals!
        built.payments.each { |payment| payment.update!(amount: built.reload.total) }
        built.reload
      end

      it 'keeps an order-level discount instead of re-competing it per child' do
        paid = cart.total
        group = described_class.call(cart: cart).value

        expect(group.total).to eq(paid)
        expect(group.orders.sum(&:discount_total)).to eq(-6)
        expect(group.orders.map { |order| order.discounts.count }).to all(eq(1))
      end

      # An order-level fee — a payment surcharge, handling — was charged for
      # the checkout as a whole and hangs off nothing that can be moved, so it
      # is the one thing here divided rather than re-pointed.
      context 'with an order-level fee' do
        let(:cart) { cart_for(nil, seller, other_seller) }

        before do
          create(:fee, order: nil, cart: cart, amount: 9, kind: 'payment', label: 'Card surcharge')
          cart.reload.recalculate_totals!
          cart.payments.each { |payment| payment.update!(amount: cart.reload.total) }
        end

        it 'shares it out across the children rather than charging it once' do
          group = described_class.call(cart: cart).value

          expect(group.orders.sum(&:fee_total)).to eq(9)
        end

        it 'gives every child a share of it' do
          group = described_class.call(cart: cart).value
          order_level = group.orders.map { |order| order.fees.order_level.sum(:amount) }

          expect(order_level.size).to eq(3)
          expect(order_level).to all(be > 0)
        end

        it 'keeps the customer’s total exactly what they paid' do
          paid = cart.total
          group = described_class.call(cart: cart).value

          expect(group.total).to eq(paid)
        end
      end

      # A fee's tax was charged on the share the fee was charged on, so it has
      # to land on the same order — a tax line left behind on a fee that now
      # holds a third of the amount overstates one child and leaves its
      # siblings untaxed.
      context 'when an order-level fee was taxed' do
        let!(:tax_category) { create(:tax_category, store: store, is_default: true) }
        let(:cart) { cart_for(nil, seller, other_seller) }

        before do
          create(:tax_rate, store: store, country_code: cart.tax_country&.iso, amount: 0.2,
                            included_in_price: false, tax_category: tax_category)
          create(:fee, order: nil, cart: cart, amount: 9, kind: 'payment', label: 'Card surcharge')
          cart.reload.recalculate_totals!
          cart.payments.each { |payment| payment.update!(amount: cart.reload.total) }
        end

        it 'taxes the fee in the first place' do
          fee = cart.fees.order_level.first

          expect(cart.tax_lines.where(fee_id: fee.id).sum(:amount)).to be > 0
        end

        it 'sends each share of the tax to the order holding the fee it was charged on' do
          group = described_class.call(cart: cart).value

          group.orders.each do |order|
            order.tax_lines.where.not(fee_id: nil).each do |tax_line|
              expect(order.fees.ids).to include(tax_line.fee_id)
            end
          end
        end

        it 'divides the fee’s tax rather than duplicating or dropping it' do
          charged = cart.tax_lines.where.not(fee_id: nil).sum(:amount)
          group = described_class.call(cart: cart).value
          fee_tax = group.orders.sum { |order| order.tax_lines.where.not(fee_id: nil).sum(:amount) }

          expect(charged).to be > 0
          expect(fee_tax).to eq(charged)
        end
      end

      # A fee hanging off a line item travels with that item, and its tax has
      # to travel too — nothing else moves it, since the tax line names no line
      # item and no parcel of its own.
      context 'when a fee on one seller’s item was taxed' do
        let!(:tax_category) { create(:tax_category, store: store, is_default: true) }
        let(:cart) { cart_for(nil, seller) }

        before do
          create(:tax_rate, store: store, country_code: cart.tax_country&.iso, amount: 0.2,
                            included_in_price: false, tax_category: tax_category)
          create(:fee, order: nil, cart: cart, line_item: cart.line_items.reload.last,
                       amount: 10, kind: 'gift_wrap', label: 'Gift wrap')
          cart.reload.recalculate_totals!
          cart.payments.each { |payment| payment.update!(amount: cart.reload.total) }
        end

        it 'moves the fee’s tax onto the order that took the fee' do
          group = described_class.call(cart: cart).value

          group.orders.each do |order|
            order.tax_lines.where.not(fee_id: nil).each do |tax_line|
              expect(order.fees.ids).to include(tax_line.fee_id)
            end
          end
        end

        it 'leaves the tax on the child holding the item it was charged for' do
          group = described_class.call(cart: cart).value
          taxed = group.orders.select { |order| order.tax_lines.where.not(fee_id: nil).any? }

          expect(taxed.size).to eq(1)
          expect(taxed.first.fees.count).to eq(1)
        end
      end

      # A fee on a parcel holding two sellers' goods is divided with it, so its
      # tax divides the same way. Left whole, one child pays all the tax on a
      # charge it only half carries and its sibling pays none — and because
      # nothing is lost in aggregate, totals alone never show it.
      context 'when a fee on a shared parcel was taxed' do
        let!(:tax_category) { create(:tax_category, store: store, is_default: true) }
        let(:cart) { cart_for(nil, seller) }

        before do
          create(:tax_rate, store: store, country_code: cart.tax_country&.iso, amount: 0.2,
                            included_in_price: false, tax_category: tax_category)
          create(:fee, order: nil, cart: cart, fulfillment: cart.fulfillments.first,
                       amount: 10, kind: 'handling', label: 'Handling')
          cart.reload.recalculate_totals!
          cart.payments.each { |payment| payment.update!(amount: cart.reload.total) }
        end

        it 'divides the fee across both halves' do
          group = described_class.call(cart: cart).value
          shares = group.orders.map { |order| order.fees.sum(:amount) }

          expect(shares).to all(be > 0)
          expect(shares.sum).to eq(10)
        end

        it 'divides the fee’s tax alongside the fee rather than leaving it whole' do
          group = described_class.call(cart: cart).value
          taxes = group.orders.map { |order| order.tax_lines.where.not(fee_id: nil).sum(:amount) }

          expect(taxes).to all(be > 0)
        end

        it 'keeps each child’s fee tax proportional to the fee it holds' do
          group = described_class.call(cart: cart).value

          group.orders.each do |order|
            fee = order.fees.sum(:amount)
            tax = order.tax_lines.where.not(fee_id: nil).sum(:amount)

            expect(tax).to eq((fee * 0.2).round(2))
          end
        end
      end
    end

    describe 'the payment' do
      let(:cart) { cart_for(nil, seller) }
      let(:group) { described_class.call(cart: cart).value }

      it 'moves onto the group rather than any one order' do
        expect(group.payments.count).to eq(1)
        expect(group.orders.flat_map(&:payments)).to be_empty
      end

      it 'records one share per child order' do
        expect(group.payment_splits.count).to eq(2)
      end

      it 'shares out exactly what was charged' do
        payment = group.payments.first
        shares = group.payment_splits.sum(:authorized_amount)

        expect(shares).to eq(payment.amount)
      end

      it 'gives each child a share matching its own total' do
        group.orders.each do |order|
          share = order.payment_splits.sum(:authorized_amount)
          expect(share).to eq(order.total)
        end
      end

      # A share that recorded nothing captured would report every child of a
      # fully paid checkout as merely authorised — two unpaid-looking orders
      # for money that is already in the bank.
      it 'records the share as captured when the payment already settled' do
        expect(group.payments.first).to be_completed

        group.orders.each do |order|
          expect(order.payment_splits.sum(:captured_amount)).to eq(order.total)
          expect(order.payment_status).to eq('paid')
        end
      end

      # A gift card becomes a store-credit payment beside the card charge, and
      # both divide the same way — one attribution rule for every source, no
      # priority ordering. A seller's order is therefore not "paid by card" or
      # "paid by gift card" but by its portion of each, which is what stops a
      # part-credited basket overstating what the gateway holds against one
      # seller.
      context 'when a gift card pays part of it' do
        let(:customer) { create(:user) }
        let(:gift_card) { create(:gift_card, store: store, amount: 12, customer: customer) }

        let(:cart) do
          built = create(:cart_ready_for_delivery, store: store, line_items_count: 2, customer: customer)
          seller_line = built.line_items.reload.last
          seller_line.variant.update!(seller: seller)
          seller_line.update_columns(seller_id: seller.id)

          create(:store_credit_payment_method, store: store) if Spree::PaymentMethod::StoreCredit.none?
          built.apply_gift_card(gift_card)
          built.reload.recalculate_totals!

          outstanding = built.total - built.payments.sum(:amount)
          if outstanding.positive?
            card = Spree::PaymentMethod.where.not(type: 'Spree::PaymentMethod::StoreCredit').first
            create(:payment, cart: built, order: nil, payment_method: card, amount: outstanding)
          end

          built.reload
        end

        it 'takes both payments onto the group' do
          expect(group.payments.count).to be >= 2
          expect(group.orders.flat_map(&:payments)).to be_empty
        end

        it 'divides every payment across both children rather than one each' do
          group.payments.each do |payment|
            expect(payment.payment_splits.map(&:order_id).uniq).to match_array(group.orders.map(&:id))
          end
        end

        it 'gives each child shares across all payments adding up to its own total' do
          group.orders.each do |order|
            expect(order.payment_splits.sum(:authorized_amount)).to eq(order.total)
          end
        end

        it 'shares out every penny the customer paid, by whatever means' do
          expect(group.payment_splits.sum(:authorized_amount)).to eq(group.payments.sum(:amount))
        end
      end
    end

    # The commission engine listens for order.placed, which every child
    # publishes on its own — so a split checkout charges each seller with no
    # marketplace code in the commission engine at all.
    describe 'commission', :events do
      let(:cart) { cart_for(nil, seller) }

      before { create(:commission_rate, store: store, kind: 'percentage', value: 10, enabled: true) }

      it 'charges the seller’s order and leaves first-party alone' do
        group = described_class.call(cart: cart).value

        seller_order = group.orders.find_by(seller: seller)
        first_party_order = group.orders.find_by(seller_id: nil)

        expect(seller_order.commission_lines).to be_present
        expect(first_party_order.commission_lines).to be_empty
      end
    end

    describe 'replay' do
      let(:cart) { cart_for(seller, other_seller) }

      it 'returns the same group rather than splitting twice' do
        first = described_class.call(cart: cart).value
        second = described_class.call(cart: cart.reload).value

        expect(second.id).to eq(first.id)
        expect(Spree::OrderGroup.count).to eq(1)
        expect(Spree::Order.count).to eq(2)
      end
    end

    describe 'the group' do
      let(:group) { described_class.call(cart: cart_for(nil, seller)).value }

      it 'totals what the children came to' do
        expect(group.total).to eq(group.orders.sum(&:total))
      end

      it 'names the sellers it reached' do
        expect(group.sellers).to contain_exactly(seller)
      end

      it 'is the cart’s completion result' do
        expect(group.cart.order_group).to eq(group)
      end
    end
  end
end
