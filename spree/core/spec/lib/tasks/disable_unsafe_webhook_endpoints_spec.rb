require 'spec_helper'
require 'rake'

describe 'spree:upgrade:disable_unsafe_webhook_endpoints' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:disable_unsafe_webhook_endpoints' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'disable_unsafe_webhook_endpoints.rake')
  end

  before do
    subject.reenable
    allow(Spree::WebhookMailer).to receive(:endpoint_disabled)
  end

  # An endpoint saved before the current URL checks existed.
  def saved_earlier(url, **attributes)
    build(:webhook_endpoint, url: url, **attributes).tap { |endpoint| endpoint.save!(validate: false) }
  end

  it 'switches off an endpoint at a loopback address written as a host name, without an email' do
    endpoint = saved_earlier('http://127.1:5432/')

    expect { subject.invoke }.to output(/Switched off 1 webhook endpoint/).to_stdout

    endpoint.reload
    expect(endpoint.active).to be false
    expect(endpoint.disabled_reason).to eq('Url must not point to an internal or private network address')
    expect(Spree::WebhookMailer).not_to have_received(:endpoint_disabled)
  end

  it 'switches off an endpoint whose URL is malformed' do
    endpoint = saved_earlier('http://[https://example.com/x]/latest/meta-data/')

    expect { subject.invoke }.to output.to_stdout

    expect(endpoint.reload.active).to be false
  end

  it 'leaves a plain-http endpoint at a public host running' do
    endpoint = saved_earlier('http://hooks.example.com/spree')

    expect { subject.invoke }.to output(/Switched off 0 webhook endpoint/).to_stdout

    expect(endpoint.reload.active).to be true
  end

  it 'leaves an endpoint running when its host does not resolve during the run' do
    allow(Resolv).to receive(:getaddresses).and_return([])
    endpoint = saved_earlier('https://hooks.example.com/spree')

    expect { subject.invoke }.to output(/Switched off 0 webhook endpoint/).to_stdout

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

    expect { subject.invoke }.to output(/Could not switch off #{unsaved.prefixed_id}.*Switched off 1 webhook endpoint.*Could not switch off 1 webhook endpoint/m).to_stdout

    expect(unsaved.reload.active).to be true
    expect(switched_off.reload.active).to be false
    expect(Rails.error).to have_received(:report).once
  end

  it 'skips endpoints that are already switched off' do
    endpoint = saved_earlier('http://127.1/', active: false, disabled_reason: 'Manually disabled')

    expect { subject.invoke }.to output(/Switched off 0 webhook endpoint/).to_stdout

    expect(endpoint.reload.disabled_reason).to eq('Manually disabled')
  end
end
