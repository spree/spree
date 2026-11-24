require 'spec_helper'

RSpec.describe Spree::MaintenanceTasks::Upgrade::BackfillStoreCreditRefunds do
  let(:order) { create(:completed_order_with_totals) }
  let!(:card) { create(:payment, order: order, amount: 30, status: 'completed') }
  let!(:second_card) { create(:payment, order: order, amount: 20, status: 'completed') }
  let(:return_record) { create(:return, order: order) }

  # Issued before credit was recorded as refunds: it names its order, nothing more.
  let!(:credit) do
    create(:store_credit, refunded_order: order, customer: order.customer, store: order.store,
                          amount: 40, originator: return_record)
  end

  def run_task(dry_run: false)
    result = Spree::MaintenanceTasks::Start.call(task_name: described_class.name, dry_run: dry_run, initiated_via: 'cli')
    Spree::MaintenanceTasks::RunJob.perform_now(result.value.id)
    result.value.reload
  end

  it 'records the credit as refunds against the order payments, oldest first' do
    run = run_task

    refunds = credit.refunds.order(:id)
    expect(refunds.map { |refund| [refund.payment, refund.amount] }).to eq([[card, 30], [second_card, 10]])
    expect(refunds).to all(have_attributes(status: 'completed', transaction_id: credit.prefixed_id,
                                           order: order, originator: return_record))
    expect(order.reload.payment_total).to eq(10)
    expect(run.tallies).to include('credits_backfilled' => 1)
  end

  it 'records what the payments allow and reports the rest' do
    create(:refund, payment: second_card, amount: 20)

    run = run_task

    expect(credit.refunds.sum(:amount)).to eq(30)
    expect(run.tallies).to include('credits_backfilled' => 1, 'credits_partly_unallocated' => 1)
  end

  # The money went back long ago: no webhook, and no seller earnings reversal.
  it 'publishes no refund events' do
    allow(Spree::Events).to receive(:publish).and_call_original

    Spree::Events.enable { run_task }

    expect(credit.refunds).to be_present
    expect(Spree::Events).not_to have_received(:publish).with(/\Arefund\.|\Apayment\.refunded/, any_args)
  end

  it 'reports a credit no payment can take, and writes nothing for it' do
    create(:refund, payment: card, amount: 30)
    create(:refund, payment: second_card, amount: 20)

    run = run_task

    expect(credit.refunds).to be_empty
    expect(run.tallies).to include('credits_unallocatable' => 1)
    expect(run.tallies).not_to have_key('credits_backfilled')
  end

  # Another run may record the credit after this one listed it.
  it 'skips a credit recorded since it was listed' do
    task = described_class.new
    task.run = Spree::MaintenanceTasks::Start.call(task_name: described_class.name, dry_run: false, initiated_via: 'cli').value
    listed = task.collection.to_a
    create(:refund, payment: card, amount: 5, store_credit: credit, transaction_id: credit.prefixed_id)

    listed.each { |record| task.process(record) }

    expect(credit.refunds.count).to eq(1)
    expect(task.tallies).to include('credits_already_recorded' => 1)
  end

  it 'changes nothing on a second run' do
    run_task

    expect { run_task }.not_to change(Spree::Refund, :count)
  end

  # The second credit finds only what the first left, as it would in a real run.
  it 'previews two credits competing for the same payments as a run would record them' do
    create(:store_credit, refunded_order: order, customer: order.customer, store: order.store, amount: 30)

    run = run_task(dry_run: true)

    expect(Spree::Refund.count).to eq(0)
    expect(run.tallies).to include('credits_would_backfill' => 2, 'credits_would_be_partly_unallocated' => 1)
  end

  it 'reports without writing in a dry run' do
    run = run_task(dry_run: true)

    expect(credit.refunds).to be_empty
    expect(run.tallies).to include('credits_would_backfill' => 1)
  end
end
