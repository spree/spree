require 'spec_helper'
require 'rake'

Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
load SpreeAdyen::Engine.root.join('lib', 'tasks', 'configure_adyen_gateways.rake')

RSpec.describe 'spree:upgrade:configure_adyen_gateways' do
  subject(:run_task) do
    task = Rake::Task['spree:upgrade:configure_adyen_gateways']
    task.reenable
    task.invoke
  end

  let(:store) { @default_store }
  let!(:first) { create(:adyen_gateway, store: store) }
  let!(:second) { create(:adyen_gateway, store: store) }

  before { allow(SpreeAdyen::Configure).to receive(:call) }

  it 'configures every Adyen method' do
    create(:check_payment_method, store: store)

    expect { run_task }.to output(/Configured 2 Adyen payment method/).to_stdout
    expect(SpreeAdyen::Configure).to have_received(:call).with(first)
    expect(SpreeAdyen::Configure).to have_received(:call).with(second)
  end

  it 'moves the previous HMAC key out of the metadata into its preference' do
    first.update!(metadata: { 'previous_hmac_key' => 'AB' * 32, 'kept' => 'yes' })

    expect { run_task }.to output.to_stdout

    expect(first.reload.metadata).to eq('kept' => 'yes')
    expect(first.preferred_previous_hmac_key).to eq('AB' * 32)
  end

  it 'carries on past a failure and then stops with the reasons' do
    allow(SpreeAdyen::Configure).to receive(:call).with(first).and_raise(Spree::Core::GatewayError, 'Adyen refused the request')

    expect { run_task }.to raise_error(SystemExit).and output(/payment method #{first.id}: Adyen refused the request/).to_stdout
    expect(SpreeAdyen::Configure).to have_received(:call).with(second)
  end
end
