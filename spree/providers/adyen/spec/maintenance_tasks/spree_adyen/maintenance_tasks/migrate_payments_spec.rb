require 'spec_helper'

RSpec.describe SpreeAdyen::MaintenanceTasks::MigratePayments do
  let(:store) { @default_store }
  let(:gateway) { create(:adyen_gateway, store: store) }
  let(:order) { create(:order, store: store, total: 10) }

  def run_task(dry_run: false)
    result = Spree::MaintenanceTasks::Start.call(task_name: described_class.name, initiated_via: 'cli', dry_run: dry_run)
    Spree::MaintenanceTasks::RunJob.perform_now(result.value.id)
    result.value.reload
  end

  def legacy_payment(response_code: 'PSPLEGACY0000001', status: 'completed')
    create(:payment, order: order, payment_method: gateway, amount: 10, response_code: response_code,
                     source: nil, skip_source_requirement: true).tap { |payment| payment.update_columns(status: status) }
  end

  def custom_field_definition(key)
    Spree::CustomFieldDefinition.find_or_create_by!(store: store, namespace: 'adyen', key: key, resource_type: 'Spree::Payment') do |definition|
      definition.label = key.humanize
      definition.field_type = 'short_text'
    end
  end

  it "copies a legacy checkout payment's response code into its PSP reference, leaving the code" do
    payment = legacy_payment

    run = run_task

    expect(payment.reload.metadata['adyen_psp_reference']).to eq('PSPLEGACY0000001')
    expect(payment.response_code).to eq('PSPLEGACY0000001')
    expect(run.tallies['converted']).to eq(1)
  end

  it 'counts a payment-session payment without a PSP reference as unrecoverable' do
    create(:adyen_payment_session, owner: order, payment_method: gateway, external_id: 'CSSESSIONLEGACY1', status: 'completed')
    payment = legacy_payment(response_code: 'CSSESSIONLEGACY1')
    allow(Rails.logger).to receive(:warn)

    run = run_task

    expect(payment.reload.metadata).not_to have_key('adyen_psp_reference')
    expect(run.tallies['unrecoverable']).to eq(1)
    expect(Rails.logger).to have_received(:warn).with(/payment #{payment.id} has no PSP reference/)
  end

  it 'moves the 5.x custom field references and removes the values and their definitions' do
    payment = legacy_payment
    capture_event = create(:payment_capture_event, payment: payment, amount: 10)
    payment.set_custom_field(custom_field_definition('capture_psp_reference'), 'PSPCAPTURE000001')
    payment.set_custom_field(custom_field_definition('cancellation_psp_reference'), 'PSPCANCEL0000001')
    payment.save!

    run_task

    expect(capture_event.reload.transaction_id).to eq('PSPCAPTURE000001')
    expect(payment.reload.metadata['adyen_cancel_references']).to eq(['PSPCANCEL0000001'])
    expect(payment.custom_fields).to be_empty
    expect(Spree::CustomFieldDefinition.where(namespace: 'adyen')).to be_empty
  end

  it 'marks capture_pending payments captured, with a capture event, and void_pending ones void' do
    capture_pending = legacy_payment(response_code: 'PSPLEGACY0000002', status: 'capture_pending')
    void_pending = legacy_payment(response_code: 'PSPLEGACY0000003', status: 'void_pending')

    run = run_task

    expect(capture_pending.reload.status).to eq('completed')
    expect(capture_pending.capture_events.sole).to have_attributes(amount: 10, status: 'completed')
    expect(void_pending.reload.status).to eq('void')
    expect(run.tallies['marked_done']).to eq(2)
  end

  it "records a capture_pending payment's capture reference on the capture event it creates" do
    payment = legacy_payment(response_code: 'PSPLEGACY0000004')
    payment.set_custom_field(custom_field_definition('capture_psp_reference'), 'PSPCAPTURE000002')
    payment.save!
    payment.update_columns(status: 'capture_pending')

    run_task

    expect(payment.reload.capture_events.sole.transaction_id).to eq('PSPCAPTURE000002')
    expect(payment.custom_fields).to be_empty
  end

  it "refreshes the order's paid total and payment status after marking a payment captured" do
    legacy_payment(response_code: 'PSPLEGACY0000005', status: 'capture_pending')
    order.update_columns(payment_total: 0)

    run_task

    expect(order.reload.payment_total).to eq(10)
    expect(order.payment_status).to eq('paid')
  end

  it 'leaves a payment as it was when migrating it fails part way' do
    payment = legacy_payment(response_code: 'PSPLEGACY0000006', status: 'capture_pending')
    allow_any_instance_of(described_class).to receive(:refresh_owner).and_raise(ActiveRecord::StatementInvalid)

    run_task

    expect(payment.reload.read_attribute(:status)).to eq('capture_pending')
    expect(payment.capture_events).to be_empty
    expect(payment.metadata).not_to have_key('adyen_psp_reference')
  end

  it 'reports without writing in a dry run' do
    payment = legacy_payment(status: 'capture_pending')

    run = run_task(dry_run: true)

    expect(payment.reload.metadata).not_to have_key('adyen_psp_reference')
    expect(payment.read_attribute(:status)).to eq('capture_pending')
    expect(run.tallies).to include('would_convert' => 1, 'would_mark_done' => 1)
  end

  it 'changes nothing on a second run' do
    payment = legacy_payment
    run_task

    expect { run_task }.not_to(change { payment.reload.updated_at })
  end
end
