require 'spec_helper'
require 'rake'

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
load SpreePaypalCheckout::Engine.root.join('lib', 'tasks', 'register_paypal_webhooks.rake')

RSpec.describe 'spree:upgrade:register_paypal_webhooks' do
  subject(:run_task) do
    task = Rake::Task['spree:upgrade:register_paypal_webhooks']
    task.reenable
    task.invoke
  end

  let(:store) { @default_store }
  let!(:first) { create(:paypal_checkout_gateway, store: store) }
  let!(:second) { create(:paypal_checkout_gateway, store: store) }
  let(:service) { instance_double(SpreePaypalCheckout::RegisterWebhook) }

  before { allow(SpreePaypalCheckout::RegisterWebhook).to receive(:new).and_return(service) }

  it 'registers the webhook of every PayPal method' do
    allow(service).to receive(:call).and_return({ 'id' => 'WH-1' })

    expect { run_task }.to output(/Registered the webhook of 2 PayPal payment method/).to_stdout
    expect(service).to have_received(:call).with(payment_method: first)
    expect(service).to have_received(:call).with(payment_method: second)
  end

  it 'ignores other payment methods' do
    create(:check_payment_method, store: store)
    allow(service).to receive(:call).and_return({ 'id' => 'WH-1' })

    expect { run_task }.to output(/2 PayPal payment method/).to_stdout
  end

  it 'carries on past a failure and then stops with the reasons' do
    allow(service).to receive(:call).with(payment_method: first).and_raise(StandardError, 'PayPal answered 401')
    allow(service).to receive(:call).with(payment_method: second).and_return({ 'id' => 'WH-2' })

    expect { run_task }.to raise_error(SystemExit).
      and output(/Registered the webhook of 1 .*payment method #{first.id}: PayPal answered 401/m).to_stdout
  end
end
