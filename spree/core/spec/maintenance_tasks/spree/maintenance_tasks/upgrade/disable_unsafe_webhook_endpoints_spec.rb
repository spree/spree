require 'spec_helper'

RSpec.describe Spree::MaintenanceTasks::Upgrade::DisableUnsafeWebhookEndpoints do
  before { allow(Spree::WebhookMailer).to receive(:endpoint_disabled) }

  def run_task(dry_run: false)
    result = Spree::MaintenanceTasks::Start.call(task_name: described_class.name,
                                                 dry_run: dry_run, initiated_via: 'cli')
    Spree::MaintenanceTasks::RunJob.perform_now(result.value.id)
    result.value.reload
  end

  # An endpoint saved before the current URL checks existed.
  def saved_earlier(url, **attributes)
    build(:webhook_endpoint, url: url, **attributes).tap { |endpoint| endpoint.save!(validate: false) }
  end

  it 'switches off an endpoint at a loopback address written as a host name, without an email' do
    endpoint = saved_earlier('http://127.1:5432/')

    run = run_task

    endpoint.reload
    expect(endpoint.active).to be false
    expect(endpoint.disabled_reason).to eq('URL must not point to an internal or private network address')
    expect(Spree::WebhookMailer).not_to have_received(:endpoint_disabled)
    expect(run).to be_succeeded
    expect(run.tallies['switched_off']).to eq(1)
  end

  it 'switches off an endpoint whose URL is malformed' do
    endpoint = saved_earlier('http://[https://example.com/x]/latest/meta-data/')

    run_task

    expect(endpoint.reload.active).to be false
  end

  it 'leaves a plain-http endpoint at a public host running' do
    endpoint = saved_earlier('http://hooks.example.com/spree')

    run = run_task

    expect(endpoint.reload.active).to be true
    expect(run.tallies).not_to have_key('switched_off')
  end

  it 'leaves an endpoint running when its host does not resolve during the run' do
    allow(Resolv).to receive(:getaddresses).and_return([])
    endpoint = saved_earlier('https://hooks.example.com/spree')

    run_task

    expect(endpoint.reload.active).to be true
  end

  it 'reports an endpoint it cannot save and switches off the rest' do
    allow(Rails.error).to receive(:report)
    unsaved = saved_earlier('http://127.1/')
    switched_off = saved_earlier('http://[::1]/hook')
    allow_any_instance_of(Spree::WebhookEndpoint).to receive(:disable!).and_wrap_original do |original, **options|
      raise ActiveRecord::RecordNotSaved, 'Failed to save the record' if original.receiver.id == unsaved.id

      original.call(**options)
    end

    run = run_task

    expect(unsaved.reload.active).to be true
    expect(switched_off.reload.active).to be false
    expect(run).to be_succeeded
    expect(run.tallies).to include('switched_off' => 1, 'failed' => 1)
    expect(Rails.error).to have_received(:report).with(an_instance_of(ActiveRecord::RecordNotSaved), context: { webhook_endpoint_id: unsaved.id })
  end

  it 'skips endpoints that are already switched off' do
    endpoint = saved_earlier('http://127.1/', active: false, disabled_reason: 'Manually disabled')

    run = run_task

    expect(endpoint.reload.disabled_reason).to eq('Manually disabled')
    expect(run.tick_count).to be_zero
  end

  describe 'dry run' do
    it 'reports what it would switch off without writing' do
      endpoint = saved_earlier('http://127.1/')

      run = run_task(dry_run: true)

      expect(endpoint.reload.active).to be true
      expect(run.tallies['would_switch_off']).to eq(1)
    end
  end
end
