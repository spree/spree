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

  # Two settings were renamed on the way onto the store, so the task can't
  # assume the global and the preference share a name.
  context 'when a renamed global was changed' do
    after do
      Spree::Config.company = false
      Spree::Config.default_stock_reservation_ttl_minutes = 10
      store.update!(
        preferred_company_field_enabled: false,
        preferred_stock_reservation_ttl_minutes: 10,
        metadata: (store.metadata || {}).except(marker)
      )
    end

    it 'copies company onto company_field_enabled' do
      Spree::Config.company = true

      expect { run_task }.to change { store.reload.preferred_company_field_enabled }.from(false).to(true)
    end

    it 'copies the reservation TTL onto its renamed preference' do
      Spree::Config.default_stock_reservation_ttl_minutes = 25

      expect { run_task }.to change { store.reload.preferred_stock_reservation_ttl_minutes }.from(10).to(25)
    end

    it 'leaves a store that already customized the renamed preference alone' do
      Spree::Config.company = true
      store.update!(preferred_company_field_enabled: true)

      expect { run_task }.not_to change { store.reload.preferred_company_field_enabled }.from(true)
    end
  end
end
