require 'spec_helper'

describe Spree::PaymentMethod, type: :model do
  it_behaves_like 'metadata'

  let(:store) { @default_store }

  # Register test gateways into the global provider registry, restoring it
  # afterwards so the mutation doesn't leak into other specs sharing the
  # process (e.g. gateway_spec's "unique api_type" check).
  around do |example|
    original = Spree.payment_methods.dup
    Spree.payment_methods << TestGateway
    Spree.payment_methods << Spree::Gateway::Test
    example.run
  ensure
    Spree.payment_methods.replace(original)
  end

  context 'visibility scopes' do
    let!(:visible_method) do
      store.payment_methods.create!(
        type: 'Spree::Gateway::Test', name: 'Visible', active: true, description: 'foofah'
      )
    end

    let!(:admin_only_method) do
      store.payment_methods.create!(
        type: 'Spree::Gateway::Test', name: 'Admin only', active: true,
        storefront_visible: false, description: 'foofah'
      )
    end

    it 'defaults to visible on the storefront' do
      expect(visible_method.storefront_visible).to be true
    end

    describe '.storefront_visible' do
      it 'returns only customer-facing methods' do
        expect(Spree::PaymentMethod.storefront_visible).to contain_exactly(visible_method)
      end
    end

    describe '.admin_only' do
      it 'returns only backoffice methods' do
        expect(Spree::PaymentMethod.admin_only).to contain_exactly(admin_only_method)
      end
    end

    describe '.available' do
      it 'returns every active method regardless of storefront visibility' do
        expect(Spree::PaymentMethod.available).to contain_exactly(visible_method, admin_only_method)
      end

      it 'excludes inactive methods' do
        visible_method.update!(active: false)
        expect(Spree::PaymentMethod.available).to contain_exactly(admin_only_method)
      end
    end

    describe '.for_store' do
      it 'excludes methods belonging to another store' do
        store_2 = create(:store)
        method_from_other_store = store_2.payment_methods.create!(
          type: 'Spree::Gateway::Test',
          name: 'Display Both',
          active: true,
          description: 'foofah'
        )
        methods = Spree::PaymentMethod.for_store(store)
        expect(methods).not_to include(method_from_other_store)
        expect(methods).to contain_exactly(visible_method, admin_only_method)
      end
    end
  end

  describe 'legacy display_on bridge' do
    let(:visible_method) { build(:check_payment_method) }
    let(:admin_only_method) { build(:check_payment_method, storefront_visible: false) }

    it 'reads the boolean back as the old tri-state value' do
      expect(visible_method.display_on).to eq('both')
      expect(admin_only_method.display_on).to eq('back_end')
    end

    it 'writes back_end as hidden and every other value as visible' do
      method = build(:check_payment_method)

      method.display_on = 'back_end'
      expect(method.storefront_visible).to be false

      method.display_on = 'front_end'
      expect(method.storefront_visible).to be true

      method.display_on = 'both'
      expect(method.storefront_visible).to be true
    end

    it 'maps available_on_front_end? onto storefront visibility' do
      expect(visible_method.available_on_front_end?).to be true
      expect(admin_only_method.available_on_front_end?).to be false
    end
  end

  describe '#auto_capture?' do
    class TestGateway < Spree::Gateway
      def provider_class
        Provider
      end
    end

    subject { gateway.auto_capture? }

    let(:gateway) { TestGateway.new(store: store) }

    context 'when the method has no capture method of its own' do
      before { stub_store_preferences(store, capture_method: capture_method) }

      context "and the store charges on dispatch" do
        let(:capture_method) { 'on_dispatch' }

        it 'is false' do
          expect(gateway.capture_method).to be_nil
          expect(subject).to be false
        end
      end

      context "and the store charges at checkout" do
        let(:capture_method) { 'checkout' }

        it 'is true' do
          expect(gateway.capture_method).to be_nil
          expect(subject).to be true
        end
      end
    end

    context 'when the method sets its own capture method' do
      before { stub_store_preferences(store, capture_method: 'on_dispatch') }

      it 'is true when it charges at checkout' do
        gateway.capture_method = 'checkout'
        expect(subject).to be true
      end

      it 'is false when it charges manually' do
        gateway.capture_method = 'manual'
        expect(subject).to be false
      end
    end

    context 'when only the legacy auto_capture column is set' do
      before { stub_store_preferences(store, capture_method: 'on_dispatch') }

      it 'is true when the column is true' do
        gateway.auto_capture = true
        expect(subject).to be true
      end

      # False only ever meant "not at checkout", so the store still decides.
      it 'defers to the store when the column is false' do
        gateway.auto_capture = false
        expect(subject).to be false
        expect(gateway.resolved_capture_method).to eq('on_dispatch')
      end
    end
  end

  describe '#resolved_capture_method' do
    let(:gateway) { Spree::Gateway::Bogus.new(store: store) }

    before { stub_store_preferences(store, capture_method: 'on_dispatch') }

    it 'inherits the store value when the method sets nothing' do
      expect(gateway.resolved_capture_method).to eq('on_dispatch')
    end

    it 'prefers its own value over the store' do
      gateway.capture_method = 'manual'
      expect(gateway.resolved_capture_method).to eq('manual')
    end

    it 'treats a blank write as going back to inheriting' do
      gateway.capture_method = 'manual'
      gateway.capture_method = ''
      expect(gateway.capture_method).to be_nil
      expect(gateway.resolved_capture_method).to eq('on_dispatch')
    end

    it 'rejects a value outside the vocabulary' do
      gateway.capture_method = 'whenever'
      expect(gateway).not_to be_valid
      expect(gateway.errors[:capture_method]).to be_present
    end

    # It is a column like `active` and `position`, not gateway configuration —
    # in the preferences blob it would render as a credential field and could
    # not be queried.
    it 'stays out of the provider preference schema' do
      expect(gateway.serialized_preference_schema.map { |field| field[:key] }).not_to include(:capture_method)
      expect(gateway.serialized_preferences.keys).not_to include('capture_method')
    end

    it 'is queryable' do
      create(:payment_method, store: store, capture_method: 'on_dispatch')

      expect(Spree::PaymentMethod.where(capture_method: 'on_dispatch')).to be_present
    end

    # The migration leaves auto_capture-false rows empty on purpose so they
    # keep inheriting. Reading them as manual here would take them out of
    # dispatch capture while the goods still went out.
    context 'when a legacy row was left for the store to decide' do
      it 'inherits the store setting rather than charging manually' do
        gateway.auto_capture = false

        expect(gateway.resolved_capture_method).to eq('on_dispatch')
        expect(gateway).to be_capture_on_dispatch
      end
    end
  end

  describe '#available_for_order?' do
    subject { payment_method.available_for_order?(order) }

    let(:payment_method) { create(:credit_card_payment_method) }
    let(:order) { create(:order, total: 100) }

    context 'when the order is not covered by store credit' do
      it { is_expected.to be(true) }
    end

    context 'when the order is partially covered by store credit' do
      let!(:store_credit_payment) { create(:store_credit_payment, order: order, amount: 50) }

      it { is_expected.to be(true) }
    end

    context 'when the order is fully covered by store credit' do
      let!(:store_credit_payment) { create(:store_credit_payment, order: order, amount: 100) }

      it { is_expected.to be(false) }
    end
  end

  describe '#available_for_store?' do
    let!(:store_1) { create(:store) }
    let!(:pm) { create(:credit_card_payment_method) }

    it 'returns true when passed a nil value' do
      eligible = pm.available_for_store?(nil)
      expect(eligible).to be true
    end

    it 'returns false if currenct store id is not included' do
      ineligible = pm.available_for_store?(store_1)
      expect(ineligible).to be false
    end

    it 'returns true if currenct store id is included' do
      eligible = pm.available_for_store?(store)
      expect(eligible).to be true
    end
  end

  describe '#source_required?' do
    let(:payment_method) { create(:credit_card_payment_method) }

    it { expect(payment_method.source_required?).to be true }
  end

  describe '#session_required?' do
    it 'returns false by default' do
      expect(build(:payment_method).session_required?).to be false
    end
  end

  describe '#payment_source_class' do
    let(:payment_method) { build(:credit_card_payment_method) }

    it { expect(payment_method.payment_source_class).to eq(Spree::CreditCard) }
  end

  describe '#payment_icon_name' do
    it { expect(build(:credit_card_payment_method, type: 'Spree::Gateway::AuthorizeNetGateway').payment_icon_name).to eq('authorizenet') }
  end

  context 'when payment method is destroyed' do
    let(:payment_method) { create(:credit_card_payment_method) }
    let!(:payment) { create(:payment, payment_method: payment_method, source: credit_card) }
    let!(:credit_card) { create(:credit_card, payment_method: payment_method) }
    let!(:gateway_customer) { create(:gateway_customer, payment_method: payment_method) }

    it 'destroys the payment method' do
      expect { payment_method.destroy }.to change(Spree::PaymentMethod, :count).by(-1).and change(Spree::CreditCard, :count).by(-1).and change(Spree::GatewayCustomer, :count).by(-1)
      expect(payment.reload.payment_method).to be_nil
      expect(credit_card.reload.payment_method).to be_nil
      expect(credit_card.reload.deleted_at).not_to be_nil
    end
  end

  describe 'position scoping' do
    it 'numbers positions per store, not across the whole table' do
      create(:payment_method, store: @default_store)
      other_store = create(:store)

      first_in_other_store = create(:payment_method, store: other_store)

      expect(first_in_other_store.position).to eq(1)
    end
  end

  describe 'payment session instrumentation' do
    it 'instruments provider-implemented session methods as gateway.spree_payments, once per call' do
      gateway_class = Class.new(Spree::Gateway) do
        def self.name = 'Spree::Testing::SessionGateway'

        def create_payment_session(order:, amount: nil, external_data: {})
          :session
        end
      end
      stub_const('Spree::Testing::SessionGateway', gateway_class)

      notifications = []
      subscription = ActiveSupport::Notifications.subscribe('gateway.spree_payments') do |*, payload|
        notifications << payload
      end

      result = gateway_class.new.create_payment_session(order: nil)

      expect(result).to eq(:session)
      expect(notifications.sole).to include(
        action: 'create_payment_session',
        payment_method_type: 'Spree::Testing::SessionGateway'
      )
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
  end
  # A preference the system writes rather than the operator supplies — a
  # secret a provider issues, an id it gives back.
  describe 'internal preferences' do
    let(:gateway_class) do
      Class.new(Spree::Gateway) do
        def self.name = 'TestInternalGateway'

        preference :api_key, :password
        preference :issued_secret, :password, internal: true
      end
    end

    it 'keeps them out of the schema, so no form offers them' do
      keys = gateway_class.serialized_preference_schema.map { |field| field[:key] }

      expect(keys).to include(:api_key)
      expect(keys).not_to include(:issued_secret)
    end

    it 'still stores and reads one, since the system depends on the value' do
      gateway = gateway_class.new
      gateway.preferred_issued_secret = 'whsec_abc'

      expect(gateway.preferred_issued_secret).to eq('whsec_abc')
    end

    it 'reports which preferences are internal' do
      gateway = gateway_class.new

      expect(gateway.preference_internal(:issued_secret)).to be(true)
      expect(gateway.preference_internal(:api_key)).to be_nil
    end

    # A gateway loaded from a build that predates this option has no such
    # reader. Schema computation rescues everything into an empty list, so
    # without a guard one old declaration would strip every field from the
    # class — including the password ones the admin form relies on.
    it 'still describes a class whose declarations predate the option' do
      gateway_class.send(:undef_method, :preferred_issued_secret_internal)
      gateway_class.instance_variable_set(:@preference_schema, nil)

      keys = gateway_class.preference_schema.map { |field| field[:key] }

      expect(keys).to include(:api_key, :issued_secret)
    end
  end
end
