require 'spec_helper'

RSpec.describe SpreePaypalCheckout::MaintenanceTasks::MigratePayments do
  let(:store) { @default_store }
  let(:gateway) { create(:paypal_checkout_gateway, store: store) }
  let(:order) { create(:order, store: store, total: 10) }

  # The table is gone from 6.0 schemas, so it is built in the shape the 0.x gem
  # left behind, once and outside the example's transaction, because MySQL
  # commits any open transaction when a table is created.
  before(:all) do
    ActiveRecord::Base.connection.create_table(described_class::LEGACY_ORDERS_TABLE, force: true) do |t|
      t.bigint :order_id, null: false
      t.bigint :payment_method_id, null: false
      t.string :paypal_id, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.json :data
      t.timestamps
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table described_class::LEGACY_ORDERS_TABLE, if_exists: true
  end

  def run_task(dry_run: false)
    result = Spree::MaintenanceTasks::Start.call(task_name: described_class.name, initiated_via: 'cli', dry_run: dry_run)
    Spree::MaintenanceTasks::RunJob.perform_now(result.value.id)
    result.value.reload
  end

  def capture_data(capture_id)
    { 'id' => 'IGNORED', 'status' => 'COMPLETED',
      'purchase_units' => [{ 'payments' => { 'captures' => [{ 'id' => capture_id, 'status' => 'COMPLETED' }] } }] }
  end

  def payment_with_capture(capture_id)
    create(:payment, order: order, payment_method: gateway, amount: 10, response_code: capture_id, status: 'completed')
  end

  def legacy_order_model
    Class.new(ActiveRecord::Base) { self.table_name = 'spree_paypal_checkout_orders' }
  end

  context 'with a payment taken through a 0.x payment session' do
    let!(:payment) { payment_with_capture('CAPTURESESSION001') }

    before do
      create(:paypal_checkout_payment_session, owner: order, payment_method: gateway, amount: 10,
                                               status: 'completed', external_id: 'SESSIONORDER00001',
                                               external_data: capture_data('CAPTURESESSION001'))
    end

    it "takes the session's order id and keeps the capture id in metadata" do
      run = run_task

      payment.reload
      expect(payment.response_code).to eq('SESSIONORDER00001')
      expect(payment.metadata['paypal_capture_id']).to eq('CAPTURESESSION001')
      expect(run.tallies['converted']).to eq(1)
    end

    it 'links the session to its payment again' do
      run_task

      expect(Spree::PaymentSession.find_by(external_id: 'SESSIONORDER00001').payment).to eq(payment.reload)
    end
  end

  context 'with a payment from the older non-session flow' do
    let!(:payment) { payment_with_capture('CAPTURELEGACY0001') }

    before do
      legacy_order_model.create!(order_id: order.id, payment_method_id: gateway.id, paypal_id: 'LEGACYORDER000001',
                                 amount: 10, data: capture_data('CAPTURELEGACY0001'))
    end

    it 'matches it through spree_paypal_checkout_orders' do
      run_task

      expect(payment.reload.response_code).to eq('LEGACYORDER000001')
      expect(payment.metadata['paypal_capture_id']).to eq('CAPTURELEGACY0001')
    end

    it 'writes nothing in a dry run' do
      run = run_task(dry_run: true)

      expect(payment.reload.response_code).to eq('CAPTURELEGACY0001')
      expect(run.tallies['would_convert']).to eq(1)
    end

    it 'converts nothing on a second run' do
      run_task
      run = run_task

      expect(payment.reload.response_code).to eq('LEGACYORDER000001')
      expect(run.tallies['converted'].to_i).to eq(0)
      expect(run.tallies['already_converted']).to eq(1)
    end
  end

  context 'with a payment it cannot match' do
    let!(:payment) { payment_with_capture('CAPTUREORPHAN0001') }

    it 'leaves it as it was, counts it and logs its id' do
      allow(Rails.logger).to receive(:warn).and_call_original

      run = run_task

      expect(payment.reload.response_code).to eq('CAPTUREORPHAN0001')
      expect(payment.metadata).not_to have_key('paypal_capture_id')
      expect(run.tallies['unmatched']).to eq(1)
      expect(Rails.logger).to have_received(:warn).with(/payment #{payment.id}\z/)
    end
  end

  context 'when another payment of the order already carries the PayPal order' do
    let!(:payment) { payment_with_capture('CAPTUREDUPLICATE1') }

    before do
      create(:payment, order: order, payment_method: gateway, amount: 10, response_code: 'DUPLICATEORDER001').
        update_columns(metadata: { 'paypal_capture_id' => 'CAPTURE60000000002' })
      legacy_order_model.create!(order_id: order.id, payment_method_id: gateway.id, paypal_id: 'DUPLICATEORDER001',
                                 amount: 10, data: capture_data('CAPTUREDUPLICATE1'))
      allow_any_instance_of(Spree::Payment).to receive(:update_columns).and_raise(ActiveRecord::RecordNotUnique)
    end

    it 'leaves it as it was and carries on' do
      run = run_task

      expect(run.status).to eq('succeeded')
      expect(payment.reload.response_code).to eq('CAPTUREDUPLICATE1')
      expect(run.tallies['unmatched']).to eq(1)
    end
  end

  it 'leaves payments taken in 6.0 alone' do
    payment = create(:payment, order: order, payment_method: gateway, amount: 10, response_code: 'ORDER60000000001')
    payment.update_columns(metadata: { 'paypal_capture_id' => 'CAPTURE60000000001' })

    run = run_task

    expect(payment.reload.response_code).to eq('ORDER60000000001')
    expect(run.tallies['already_converted']).to eq(1)
  end

  it "leaves other gateways' payments alone" do
    other = create(:payment, order: order, amount: 10, response_code: 'ch_123')

    run_task

    expect(other.reload.response_code).to eq('ch_123')
  end
end
