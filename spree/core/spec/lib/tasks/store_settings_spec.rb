require 'spec_helper'
require 'rake'

describe 'spree:store_settings:backfill_from_config' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'store_settings.rake')
  end

  let(:store) { @default_store }
  let(:marker) { 'store_settings_backfilled_from_config' }

  def run_task
    task = Rake::Task['spree:store_settings:backfill_from_config']
    task.reenable
    old = $stdout.dup
    $stdout.reopen(File::NULL, 'w')
    task.invoke
  ensure
    $stdout.reopen(old)
  end

  before do
    store.update!(preferred_address_requires_phone: false, metadata: (store.metadata || {}).except(marker))
  end

  after do
    Spree::Config.address_requires_phone = false
    store.update!(preferred_address_requires_phone: false, metadata: (store.metadata || {}).except(marker))
  end

  context 'when the global was changed from its default' do
    before { Spree::Config.address_requires_phone = true }

    it 'copies the value onto the store' do
      expect { run_task }.to change { store.reload.preferred_address_requires_phone }.from(false).to(true)
    end

    it 'marks the store so a later run leaves it alone' do
      run_task

      expect(store.reload.metadata[marker]).to be_truthy
    end

    # Preferences seed their defaults on create, so a value equal to the default
    # can't be distinguished from a deliberate one. The marker is what keeps a
    # merchant's later change from being undone by a second run.
    it 'does not re-copy after the merchant changes the value back' do
      run_task
      store.update!(preferred_address_requires_phone: false)

      expect { run_task }.not_to change { store.reload.preferred_address_requires_phone }.from(false)
    end
  end

  context 'when the global is still at its default' do
    before { Spree::Config.address_requires_phone = false }

    it 'copies nothing' do
      expect { run_task }.not_to change { store.reload.preferred_address_requires_phone }.from(false)
    end
  end
end
