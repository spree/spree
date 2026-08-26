require 'spec_helper'

module Spree
  describe Carts::Complete do
    let(:store) { @default_store }

    # Payment-covered cart, one completion attempt away from an order.
    let(:ready_cart) { create(:cart_ready_to_complete, store: store) }

    # The split partitions on this column, so it has to survive the copy from
    # cart line to order line — and be right at the moment of placement, since
    # the catalog can change hands while an item sits in a cart.
    describe 'the seller snapshot' do
      let(:seller) { create(:seller, store: store, name: 'Sparks Audio') }

      it 'carries onto the order lines' do
        ready_cart.line_items.each do |line_item|
          line_item.variant.product.update!(seller: seller)
          line_item.update!(seller: seller)
        end

        result = described_class.call(cart: ready_cart)

        expect(result).to be_success
        expect(result.value.line_items.map(&:seller_id).uniq).to eq([seller.id])
      end

      it 'leaves first-party lines without a seller' do
        result = described_class.call(cart: ready_cart)

        expect(result.value.line_items.map(&:seller_id).uniq).to eq([nil])
      end
    end

    describe 'the three-phase pipeline' do
      subject { described_class.call(cart: ready_cart) }

      it 'completes the cart into a placed order' do
        result = subject

        expect(result).to be_success
        order = result.value
        expect(order).to be_a(Spree::Order)
        expect(order.status).to eq('placed')
        expect(order.completed_at).to be_present
        expect(order.cart_id).to eq(ready_cart.id)
        expect(ready_cart.reload.completed_at).to be_present
        expect(ready_cart.completing_at).to be_nil
      end

      it 'copies line items, fulfillments and addresses — never sharing rows' do
        order = subject.value

        expect(order.line_items.count).to eq(ready_cart.line_items.count)
        expect(order.line_items.ids).not_to match_array(ready_cart.line_items.ids)
        expect(order.fulfillments.count).to eq(ready_cart.reload.fulfillments.count)
        expect(order.ship_address_id).not_to eq(ready_cart.ship_address_id)
        expect(order.email).to eq(ready_cart.email)
        expect(order.token).to eq(ready_cart.token)
      end

      it 'is idempotent — replay returns the same order' do
        first = subject.value
        replay = described_class.call(cart: ready_cart.reload)

        expect(replay).to be_success
        expect(replay.value.id).to eq(first.id)
        expect(Spree::Order.where(cart_id: ready_cart.id).count).to eq(1)
      end

      it 'rejects a concurrent completion in flight' do
        ready_cart.update_columns(completing_at: Time.current)

        result = described_class.call(cart: ready_cart)
        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('completion_in_progress')
      end

      it 'takes over a stale completion lock' do
        ready_cart.update_columns(completing_at: 10.minutes.ago)

        expect(subject).to be_success
      end

      it 'returns cart_changed on expected_total drift' do
        result = described_class.call(cart: ready_cart, expected_total: ready_cart.total + 5)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('cart_changed')
        expect(ready_cart.reload.completed_at).to be_nil
      end

      it 'returns structured validation errors when requirements are unmet' do
        ready_cart.update_columns(email: nil)

        result = described_class.call(cart: ready_cart)
        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('validation_failed')
        expect(result.error.value[:errors]).to be_present
      end

      it 'rejects a variant discontinued after it entered the cart' do
        ready_cart.line_items.first.variant.update_columns(discontinue_on: 1.minute.ago)

        result = described_class.call(cart: ready_cart)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('validation_failed')
        expect(result.error.value[:errors].map { |error| error[:code] }).to include('discontinued')
      end
    end

    describe 'tax lifecycle' do
      it 'tells the tax engine the sale is final' do
        provider = instance_double(Spree::TaxProvider::Internal, estimate: nil, commit: nil)
        allow_any_instance_of(Spree::Order).to receive(:tax_provider).and_return(provider)
        allow_any_instance_of(Spree::Cart).to receive(:tax_provider).and_return(provider)

        order = described_class.call(cart: ready_cart).value

        expect(provider).to have_received(:commit).with(order)
      end

      it 'does not re-estimate while copying the cart onto the order' do
        provider = instance_double(Spree::TaxProvider::Internal, estimate: nil, commit: nil)
        allow_any_instance_of(Spree::Order).to receive(:tax_provider).and_return(provider)

        described_class.call(cart: ready_cart)

        # Only commit files the sale. An estimate here would be a remote call per
        # line item for an external engine, and its answer is discarded anyway.
        expect(provider).not_to have_received(:estimate)
      end

      # The copy is the source of truth: whatever the cart was taxed is what the
      # order owes. Left to itself, creating the order's line items fires
      # LineItem#update_tax_charge and writes a second row per item — the order's
      # own totals still read correctly, so the damage lands on whatever reads
      # the rows: an invoice, an e-invoicing export, a tax return.
      context 'when the cart carries tax rows' do
        let(:tax_category) { create(:tax_category) }
        let!(:rate) do
          create(:tax_rate, store: store, country_code: ready_cart.tax_country&.iso, amount: 0.1,
                            included_in_price: false, tax_category: tax_category)
        end

        before do
          # The line item copies its category from the variant on every save, so
          # the variant is where it has to be set.
          ready_cart.line_items.each do |line_item|
            line_item.variant.update!(tax_category: tax_category)
            line_item.reload.update!(tax_category: tax_category)
          end
          ready_cart.recalculate_totals!

          # The factory sized the payment before this tax existed, so the cart is
          # now a pound short and completion would stop at payment processing —
          # which reads here as "the order has no tax rows".
          ready_cart.payments.first.update!(amount: ready_cart.reload.total)
        end

        # Queried directly rather than through order.tax_lines: the association
        # is loaded during the copy and reports the cart's rows here.
        def order_rows(order)
          Spree::TaxLine.where(order_id: order.id)
        end

        it 'gives the order exactly one tax row per taxed line item' do
          expect(ready_cart.tax_lines.reload.where.not(line_item_id: nil).count).to eq(1)

          result = described_class.call(cart: ready_cart)
          # Asserted explicitly: a failed completion returns the cart, and every
          # row assertion below would then read zero for the wrong reason.
          expect(result).to be_success

          rows = order_rows(result.value).where.not(line_item_id: nil)

          expect(rows.count).to eq(1)
          expect(rows.pluck(:line_item_id).uniq.length).to eq(1)
        end

        it 'keeps the summed rows equal to the order additional tax total' do
          result = described_class.call(cart: ready_cart)
          expect(result).to be_success

          order = result.value
          expect(order_rows(order).sum(:amount)).to eq(order.additional_tax_total)
        end
      end
    end

    describe 'business customer' do
      let(:customer) { create(:customer) }
      let(:company) { create(:company, store: store) }

      before { ready_cart.update!(customer: customer) }

      # Without this the exemption applies during checkout and vanishes from the
      # placed order, so commit and refund work from different facts.
      it 'carries the node onto the order' do
        create(:company_membership, company: company, customer: customer)
        ready_cart.update!(company: company)

        order = described_class.call(cart: ready_cart).value

        expect(order.company).to eq(company)
      end

      it 'carries a node the buyer resolved to without naming it' do
        create(:company_membership, company: company, customer: customer)

        order = described_class.call(cart: ready_cart.reload).value

        expect(order.company).to eq(company)
      end

      it 'leaves a consumer order with no company' do
        expect(described_class.call(cart: ready_cart).value.company).to be_nil
      end
    end

    describe 'tax identifier snapshot' do
      let(:customer) { create(:user) }

      before { ready_cart.update!(customer: customer) }

      it 'freezes the customer registration onto the order' do
        create(:tax_identifier, owner: customer, kind: 'eu_vat', value: 'DE123456789')

        order = described_class.call(cart: ready_cart).value

        snapshot = order.tax_identifier
        expect(snapshot.value).to eq('DE123456789')
        expect(snapshot.source).to eq('customer')
        expect(snapshot).to be_readonly
      end

      it 'records a checkout override as such' do
        create(:tax_identifier, owner: customer, kind: 'eu_vat', value: 'DE123456789')
        create(:tax_identifier, owner: ready_cart, kind: 'eu_vat', value: 'DE999999999')

        order = described_class.call(cart: ready_cart).value

        expect(order.tax_identifier.value).to eq('DE999999999')
        expect(order.tax_identifier.source).to eq('override')
      end

      it 'stamps a company registration as such' do
        company = create(:company, store: store)
        create(:company_membership, company: company, customer: customer)
        ready_cart.update!(company: company)
        create(:tax_identifier, owner: company, kind: 'eu_vat', value: 'DE777777777')

        order = described_class.call(cart: ready_cart).value

        expect(order.tax_identifier.value).to eq('DE777777777')
        expect(order.tax_identifier.source).to eq('company')
        # The copy belongs to the order, not the company it was resolved from.
        expect(order.tax_identifier.owner).to eq(order)
      end

      it 'copies nothing for a consumer sale' do
        order = described_class.call(cart: ready_cart).value

        expect(order.tax_identifier).to be_nil
      end
    end

    describe 'guest checkout policy' do
      it 'fails when the channel forbids guest checkout and the cart has no customer' do
        allow_any_instance_of(Spree::Cart).to receive(:guest_checkout_disallowed?).and_return(true)

        result = described_class.call(cart: ready_cart)
        expect(result).to be_failure
        expect(ready_cart.reload.completed_at).to be_nil
      end
    end

    describe 'stock reservations' do
      it 'releases reservations on successful completion' do
        line_item = ready_cart.line_items.first
        stock_level = line_item.variant.stock_levels.first
        Spree::StockReservation.create!(cart: ready_cart, order: nil, line_item: line_item, stock_level: stock_level, quantity: 1, expires_at: 1.hour.from_now)

        expect { described_class.call(cart: ready_cart) }.to change { Spree::StockReservation.count }.by(-1)
      end
    end

    describe 'admin/B2B order path' do
      let(:order) { create(:order_with_line_items) }

      it 'finalizes a draft order through the same service' do
        create(:payment, order: order, amount: order.total, status: 'pending')

        result = described_class.call(cart: order)
        expect(result).to be_success
        expect(order.reload.completed_at).to be_present
      end

      it 'refuses a canceled draft order' do
        order.update_columns(status: 'canceled', canceled_at: Time.current)

        result = described_class.call(cart: order)
        expect(result).to be_failure
        expect(order.reload.completed_at).to be_nil
      end
    end

    describe 'payment failure compensation' do
      it 'rolls the draft order back and re-points money records to the cart' do
        # A payment that never completes: processing is a no-op, so coverage
        # stays below total and the pre-capture rollback arm fires.
        allow(Spree::Payments::Process).to receive(:call).and_return(double(failure?: false))
        payment = ready_cart.payments.first

        result = described_class.call(cart: ready_cart)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('payment_failed')
        expect(Spree::Order.where(cart_id: ready_cart.id)).to be_none
        expect(payment.reload.cart_id).to eq(ready_cart.id)
        expect(payment.order_id).to be_nil
        expect(ready_cart.reload.completing_at).to be_nil
        expect(ready_cart.completed_at).to be_nil
      end
    end

    describe 'net-terms completion (payment_pending)' do
      let(:uncovered_cart) { create(:cart_ready_for_delivery, store: store) }

      it 'does not waive the payment requirement on carts — net terms is a draft-order flow' do
        result = described_class.call(cart: uncovered_cart, payment_pending: true)

        expect(result).to be_failure
        expect(result.error.value[:code]).to eq('validation_failed')
        expect(result.error.value[:errors].map { |error| error[:code] }).to include('payment_required')
      end

      it 'completes without capturing when the payment is authorized but pending' do
        uncovered_cart.payments.create!(payment_method: Spree::PaymentMethod.first, amount: uncovered_cart.total, status: 'pending')

        result = described_class.call(cart: uncovered_cart, payment_pending: true)

        expect(result).to be_success
        expect(result.value.status).to eq('placed')
        expect(result.value.payment_total).to eq(0)
      end
    end

    describe 'crash-window replay' do
      it 'heals a completion that died between the order commit and the cart stamp' do
        order = described_class.call(cart: ready_cart).value
        # Simulate the crash window: order placed, cart stamp lost
        # (update_all — the readonly completed-cart guard blocks AR writes).
        Spree::Cart.where(id: ready_cart.id).update_all(completed_at: nil, completing_at: Time.current)
        crashed_cart = Spree::Cart.find(ready_cart.id)

        result = described_class.call(cart: crashed_cart)

        expect(result).to be_success
        expect(result.value.id).to eq(order.id)
        expect(crashed_cart.reload.completed_at).to be_present
        expect(crashed_cart.completing_at).to be_nil
        expect(Spree::Order.where(cart_id: crashed_cart.id).count).to eq(1)
      end

      it 'returns a canceled order from a previous completion without re-finalizing' do
        order = described_class.call(cart: ready_cart).value
        order.update_columns(status: 'canceled', canceled_at: Time.current)

        result = described_class.call(cart: ready_cart.reload)

        expect(result).to be_success
        expect(result.value.status).to eq('canceled')
      end
    end

    describe 'before_finalize hook' do
      after { Spree.hooks.clear! }

      it 'dispatches with the workflow instance before the order places' do
        seen = nil
        Spree.hooks.register('carts.complete.before_finalize') do |flow|
          seen = { order_placed: flow.order.placed?, cart_id: flow.cart.id }
        end

        described_class.call(cart: ready_cart)

        expect(seen).to eq(order_placed: false, cart_id: ready_cart.id)
      end
    end

    describe 'coupon codes' do
      it 're-points an applied cart coupon code to the order and marks it used' do
        promotion = create(:promotion_with_item_adjustment, adjustment_rate: 2, kind: :coupon_code, store: store, multi_codes: true, number_of_codes: 1)
        coupon_code = promotion.coupon_codes.first
        coupon_code.update!(cart: ready_cart)
        ready_cart.update_columns(coupon_code: coupon_code.code)

        result = described_class.call(cart: ready_cart)

        expect(result).to be_success
        expect(coupon_code.reload.state).to eq('used')
        expect(coupon_code.order_id).to eq(result.value.id)
        expect(coupon_code.cart_id).to be_nil
      end

      it 'detaches codes whose promotion did not apply' do
        promotion = create(:promotion, kind: :coupon_code, store: store)
        coupon_code = create(:coupon_code, promotion: promotion, cart: ready_cart)

        result = described_class.call(cart: ready_cart)

        expect(result).to be_success
        expect(coupon_code.reload.state).to eq('unused')
        expect(coupon_code.order_id).to be_nil
      end
    end
  end
end
