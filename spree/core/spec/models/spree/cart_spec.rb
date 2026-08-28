require 'spec_helper'

describe Spree::Cart, type: :model do
  it_behaves_like 'a purchase carrying a PO reference', factory: :cart

  let(:store) { @default_store }
  let(:customer) { create(:user) }

  it_behaves_like 'a purchase constrained to channel-served markets' do
    let(:purchase_factory) { :cart }
  end

  describe 'Validations' do
    describe '#email' do
      it 'allows a blank email — presence during checkout is a Requirements concern' do
        expect(build(:cart, store: store, email: nil)).to be_valid
      end

      it 'rejects a malformed email whenever one is present' do
        cart = build(:cart, store: store, email: 'not-an-email')

        expect(cart).not_to be_valid
        expect(cart.errors[:email]).to be_present
      end

      it 'rejects an email longer than 254 characters' do
        expect(build(:cart, store: store, email: "#{'a' * 250}@x.com")).not_to be_valid
      end
    end
  end

  describe '#checkout_steps' do
    let(:cart) { build(:cart, store: store) }

    before { allow(cart).to receive_messages(delivery_step_required?: true) }

    context 'when confirmation not required' do
      before do
        allow(cart).to receive_messages confirmation_required?: false
        allow(cart).to receive_messages payment_required?: true
      end

      specify do
        expect(cart.checkout_steps).to eq(%w(address delivery payment complete))
      end
    end

    context 'when confirmation required' do
      before do
        allow(cart).to receive_messages confirmation_required?: true
        allow(cart).to receive_messages payment_required?: true
      end

      specify do
        expect(cart.checkout_steps).to eq(%w(address delivery payment confirm complete))
      end
    end

    context 'when delivery not required' do
      before { allow(cart).to receive_messages delivery_step_required?: false }

      specify do
        expect(cart.checkout_steps).to eq(%w(address complete))
      end
    end

    context 'when payment not required' do
      before { allow(cart).to receive_messages payment_required?: false }

      specify do
        expect(cart.checkout_steps).to eq(%w(address delivery complete))
      end
    end

    context 'when payment required' do
      before { allow(cart).to receive_messages payment_required?: true }

      specify do
        expect(cart.checkout_steps).to eq(%w(address delivery payment complete))
      end
    end
  end

  describe '#checkout_step_index' do
    let(:cart) { build(:cart, store: store) }

    before { allow(cart).to receive_messages(delivery_step_required?: true) }

    it 'always returns an integer' do
      expect(cart.checkout_step_index('imnotthere')).to be_a Integer
      expect(cart.checkout_step_index('delivery')).to be > 0
    end
  end

  describe 'lifecycle events' do
    it 'publishes cart.* lifecycle events' do
      expect(described_class.lifecycle_events_enabled).to be true
      expect(described_class.event_prefix).to eq('cart')

      registered = described_class._commit_callbacks.map(&:filter)
      expect(registered).to include(:publish_create_event, :publish_update_event, :publish_delete_event)
    end

    # The V3 cart serializer resolves by convention when spree_api is loaded;
    # core's dummy app only sees the fallback payload.
    it 'carries the prefixed id in the event payload' do
      cart = create(:cart, store: store)

      expect(cart.event_payload[:id]).to eq(cart.prefixed_id)
    end
  end

  describe 'readonly after completion' do
    let(:cart) { create(:cart, store: store) }

    it 'rejects every write path once completed' do
      cart.update_columns(completed_at: Time.current)

      reloaded = Spree::Cart.find(cart.id)
      expect(reloaded).to be_readonly
      expect { reloaded.update!(email: 'x@example.com') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { reloaded.update_columns(email: 'x@example.com') }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { reloaded.touch }.to raise_error(ActiveRecord::ReadOnlyRecord)
      expect { reloaded.destroy }.to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'lets the completion write through and locks the instance after it' do
      expect { cart.update_columns(completed_at: Time.current) }.not_to raise_error
      expect(cart).to be_readonly
    end
  end

  describe 'lifecycle' do
    it 'generates a token on create' do
      expect(create(:cart).token).to be_present
    end

    it 'is completed when completed_at is set' do
      expect(build(:cart, completed_at: Time.current)).to be_completed
      expect(build(:cart)).not_to be_completed
    end

    it 'is completing while completing_at holds the cart' do
      expect(build(:cart, completing_at: Time.current)).to be_completing
      expect(build(:cart)).not_to be_completing
    end

    it 'scopes complete/incomplete on completed_at' do
      incomplete = create(:cart)
      complete = create(:cart, completed_at: Time.current)

      expect(described_class.complete).to contain_exactly(complete)
      expect(described_class.incomplete).to contain_exactly(incomplete)
    end
  end

  describe 'line item ownership' do
    let(:cart) { create(:cart) }

    it 'owns line items and destroys them with the cart' do
      line_item = create(:line_item, order: nil, cart: cart, currency: cart.currency)

      expect(line_item.owner).to eq(cart)
      expect { cart.destroy }.to change(Spree::LineItem, :count).by(-1)
    end
  end

  describe 'order link' do
    it 'links to the order completed from it' do
      cart = create(:cart, completed_at: Time.current)
      order = create(:order, cart: cart)

      expect(cart.order).to eq(order)
    end
  end

  describe '#warnings' do
    let(:cart) { build(:cart) }

    it 'defaults to empty array' do
      expect(cart.warnings).to eq([])
    end

    it 'is a transient attribute (not persisted)' do
      cart.warnings = [{ code: 'test', message: 'test' }]
      cart.save!
      expect(cart.reload.warnings).to eq([])
    end
  end

  describe '#remove_out_of_stock_items!' do
    let(:cart) { create(:cart_with_line_items, store: store, customer: customer) }

    context 'when all items are in stock' do
      it 'does not remove any items' do
        expect { cart.remove_out_of_stock_items! }.not_to change { cart.line_items.count }
      end

      it 'sets warnings to empty array' do
        cart.remove_out_of_stock_items!
        expect(cart.warnings).to eq([])
      end
    end

    context 'when an item is out of stock' do
      before do
        cart.line_items.first.variant.stock_levels.update_all(count_on_hand: 0, backorderable: false)
      end

      it 'removes the out of stock item' do
        expect { cart.remove_out_of_stock_items! }.to change { cart.reload.line_items.count }.by(-1)
      end

      it 'populates warnings with structured data' do
        cart.remove_out_of_stock_items!
        expect(cart.warnings.length).to eq(1)
        expect(cart.warnings.first[:code]).to eq('line_item_removed')
        expect(cart.warnings.first[:message]).to be_present
        expect(cart.warnings.first[:variant_id]).to start_with('variant_')
        expect(cart.warnings.first[:line_item_id]).to start_with('li_')
      end
    end

    context 'when a product is discontinued' do
      before do
        cart.line_items.first.product.update_columns(status: 'discontinued')
      end

      it 'removes the item and populates warnings' do
        cart.remove_out_of_stock_items!
        expect(cart.warnings.length).to eq(1)
        expect(cart.warnings.first[:code]).to eq('line_item_removed')
      end
    end

    context 'when cart is empty' do
      let(:order) { create(:order, store: store, user: user) }

      it 'does nothing' do
        cart.remove_out_of_stock_items!
        expect(cart.warnings).to eq([])
      end
    end
  end

  describe '#coupon_code=' do
    it 'normalizes to a stripped, lowercased code' do
      expect(build(:cart, coupon_code: '  SAVE10  ').read_attribute(:coupon_code)).to eq('save10')
    end

    it 'tolerates nil' do
      expect(build(:cart, coupon_code: nil).read_attribute(:coupon_code)).to be_nil
    end
  end

  describe '#number' do
    it 'mirrors the prefixed id (deprecated API bridge)' do
      cart = create(:cart, store: store)

      expect(cart.number).to eq(cart.prefixed_id)
    end
  end

  describe '#name' do
    it 'returns the billing address full name' do
      bill_address = create(:address, firstname: 'John', lastname: 'Doe')
      cart = create(:cart, store: store, bill_address: bill_address)

      expect(cart.name).to eq('John Doe')
    end

    it 'falls back to the shipping address when billing is blank' do
      ship_address = create(:address, firstname: 'Jane', lastname: 'Roe')
      cart = create(:cart, store: store, bill_address: nil, ship_address: ship_address)

      expect(cart.name).to eq('Jane Roe')
    end

    it 'is nil with no addresses' do
      expect(build(:cart, store: store, bill_address: nil, ship_address: nil).name).to be_nil
    end
  end

  describe '#preferred_stock_location' do
    let(:cart) { create(:cart, store: store) }
    let(:pickup_location) { create(:stock_location, pickup_enabled: true) }

    it 'persists the pickup choice' do
      cart.update!(preferred_stock_location_id: pickup_location.id)

      expect(cart.reload.preferred_stock_location).to eq(pickup_location)
    end
  end

  describe '#recalculate_totals!' do
    it 'runs the configured totals workflow on itself' do
      cart = create(:cart, store: store)

      expect(Spree.cart_recalculate_totals_workflow).to receive(:call).with(cart: cart)
      cart.recalculate_totals!
    end
  end

  describe '#outstanding_balance' do
    it 'is total minus payment_total (carts never net refunds)' do
      expect(build(:cart, total: 100, payment_total: 40).outstanding_balance).to eq(60)
    end
  end

  describe '#associate_user!' do
    let(:cart) { create(:cart, store: store, customer: nil, email: nil) }
    let(:user) { create(:user, ship_address: create(:address), bill_address: create(:address)) }

    it 'binds the user, takes the email and copies valid default addresses' do
      cart.associate_user!(user)

      expect(cart.reload.customer).to eq(user)
      expect(cart.email).to eq(user.email)
      expect(cart.bill_address_id).to eq(user.bill_address_id)
    end

    it 'keeps an existing email when override is disabled' do
      cart.update!(email: 'original@example.com')

      cart.associate_user!(user, false)

      expect(cart.reload.email).to eq('original@example.com')
    end
  end

  describe '#merge!' do
    it 'runs the configured merge workflow and reloads' do
      cart = create(:cart, store: store)
      other_cart = create(:cart, store: store)
      workflow = class_double(Spree::Carts::Merge).as_stubbed_const

      expect(workflow).to receive(:call).with(cart: cart, other_cart: other_cart, customer: nil)

      cart.merge!(other_cart)
    end
  end

  describe 'delivery proposals' do
    let(:country) { @default_country }
    let(:state) { country.states.first || create(:state, country: country) }
    let!(:zone) { create(:zone) }
    let!(:shipping_method) do
      create(:shipping_method).tap do |method|
        method.calculator.preferred_amount = 5
        method.calculator.save
      end
    end
    let!(:stock_location) { Spree::StockLocation.first || create(:stock_location, country: country, state: state) }
    let(:ship_address) { create(:address, country: country, state: state) }
    let(:cart) { create(:cart_with_line_items, store: store, ship_address: ship_address, email: 'buyer@example.com') }

    describe '#rebuild_fulfillments!' do
      it 'builds cart-owned proposals from the current items and address' do
        cart.rebuild_fulfillments!

        expect(cart.fulfillments).to be_present
        expect(cart.fulfillments.map(&:order_id).uniq).to eq([nil])
        expect(cart.fulfillments.first.address_id).to eq(ship_address.id)
        expect(cart.fulfillments.first.delivery_rates).to be_present
      end

      it 'is idempotent and never touches a completed cart' do
        cart.rebuild_fulfillments!
        expect { cart.rebuild_fulfillments! }.not_to change { cart.fulfillments.count }

        cart.update_columns(completed_at: Time.current)
        expect(Spree::Cart.find(cart.id).rebuild_fulfillments!).to be_nil
      end
    end

    describe '#prune_undeliverable_fulfillments!' do
      it 'drops proposals with no delivery rates and records a warning per line item' do
        cart.rebuild_fulfillments!
        cart.fulfillments.each { |fulfillment| fulfillment.delivery_rates.delete_all }

        cart.prune_undeliverable_fulfillments!

        expect(cart.fulfillments.reload).to be_empty
        expect(cart.warnings.map { |warning| warning[:code] }).to include('delivery_unavailable')
      end
    end

    describe '#ensure_available_delivery_rates' do
      it 'errors when there are no deliverable proposals' do
        expect(cart.ensure_available_delivery_rates).to be(false)
        expect(cart.errors[:base]).to be_present

        cart.errors.clear
        cart.rebuild_fulfillments!
        expect(cart.ensure_available_delivery_rates).to be(true)
      end
    end

    describe '#set_fulfillments_cost' do
      it 'persists the delivery total and grand total from fulfillment costs' do
        cart.rebuild_fulfillments!
        cart.recalculate_totals!

        cart.set_fulfillments_cost

        expect(cart.reload.delivery_total).to eq(cart.fulfillments.sum(&:cost))
        expect(cart.total).to eq(cart.item_total + cart.delivery_total + cart.adjustment_total)
      end
    end

    describe '#ensure_updated_fulfillments' do
      it 'rebuilds for open carts and skips completed ones' do
        expect(cart).to receive(:rebuild_fulfillments!)
        cart.ensure_updated_fulfillments

        cart.update_columns(completed_at: Time.current)
        completed = Spree::Cart.find(cart.id)
        expect(completed).not_to receive(:rebuild_fulfillments!)
        completed.ensure_updated_fulfillments
      end
    end

    describe '#recalculate_for_address_change!' do
      it 'reprices items, rebuilds proposals and recalculates totals' do
        cart.recalculate_for_address_change!

        expect(cart.fulfillments.reload).to be_present
        expect(cart.reload.delivery_total).to be > 0
        expect(cart.total).to eq(cart.item_total + cart.delivery_total + cart.adjustment_total)
      end

      # The re-price used to be computed into memory and dropped: nothing here
      # saves the line items, and the recalculation that follows resets the
      # association cache. A destination change has to leave the new figure in the
      # column, or the customer is charged the price quoted for the old country.
      it 'persists the repriced line item, not just the in-memory attribute' do
        line_item = cart.line_items.first
        line_item.update_columns(price: 1)

        cart.recalculate_for_address_change!

        expect(cart.line_items.reload.first.price).not_to eq(1)
        expect(line_item.reload.price).to eq(line_item.variant.price_for(
          Spree::Pricing::Context.from_order(line_item.variant, cart)
        ).amount)
      end
    end
  end
end
