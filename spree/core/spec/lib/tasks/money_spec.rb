require 'spec_helper'
require 'rake'

describe 'spree:money:audit_capture_events' do
  subject { Rake::Task['spree:money:audit_capture_events'] }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'money.rake')
  end

  before { subject.reenable }

  let(:yen_payment) do
    create(:payment, amount: 1000).tap { |payment| payment.order.update_columns(currency: 'JPY') }
  end
  let(:dollar_payment) { create(:payment, amount: 10) }
  let!(:yen_event) { yen_payment.capture_events.create!(amount: 100_000) }

  before { dollar_payment.capture_events.create!(amount: 10) }

  it 'lists events in currencies without two decimals with both readings, and changes nothing' do
    expect { subject.invoke }.to output(
      /#{yen_event.prefixed_id}\t#{yen_payment.number}\tJPY\trecorded=100000\tif_from_capture=1000\tpayment_amount=1000\n.*1 capture event/m
    ).to_stdout

    expect(yen_event.reload.amount).to eq(100_000)
  end
end
