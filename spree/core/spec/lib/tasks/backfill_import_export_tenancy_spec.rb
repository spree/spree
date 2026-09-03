require 'spec_helper'
require 'rake'

RSpec.describe 'spree:upgrade:backfill_import_export_tenancy' do
  let(:store) { @default_store }
  let(:seller) { create(:seller, store: store) }
  let(:user) { create(:admin_user) }

  # Deliberately no `Rake::Task.clear`: the registry is global, and sibling
  # task specs load their rake file once at file scope, so clearing it here
  # un-defines tasks they have already registered and fails them by load
  # order alone.
  # Loaded once, not per example: redefining a task APPENDS its action, so an
  # unguarded load here would run the task body one more time on each example.
  before do
    unless Rake::Task.task_defined?('spree:upgrade:backfill_import_export_tenancy')
      load Spree::Core::Engine.root.join('lib/tasks/backfill_import_export_tenancy.rake')
    end
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
  end

  def run! = Rake::Task['spree:upgrade:backfill_import_export_tenancy'].tap(&:reenable).invoke

  # A pre-upgrade row: the polymorphic pair set, the new columns empty.
  def legacy_import(owner)
    create(:product_import, store: store, user: user).tap do |import|
      import.update_columns(store_id: nil, seller_id: nil,
                            owner_type: owner.class.base_class.to_s, owner_id: owner.id)
    end
  end

  it 'places a store-owned import and leaves it first party' do
    import = legacy_import(store)

    expect { run! }.to output(/1 placed from a store owner/).to_stdout

    expect(import.reload.store).to eq(store)
    expect(import.seller).to be_nil
  end

  it 'places a seller-owned import in the seller\'s store' do
    import = legacy_import(seller)

    expect { run! }.to output(/1 placed from a seller owner/).to_stdout

    expect(import.reload.seller).to eq(seller)
    expect(import.store).to eq(store)
  end

  it 'places an import whose owner is gone in the default store' do
    import = legacy_import(seller)
    import.update_columns(owner_id: 0)

    expect { run! }.to output(/1 orphaned import/).to_stdout

    expect(import.reload.store).to eq(store)
  end

  # A dangling store id would otherwise be written as-is, leaving store_id
  # non-NULL but pointing nowhere — invisible to every scoped query, and
  # skipped by the orphan sweep that would have rescued it.
  it 'places an import whose store is gone in the default store' do
    import = legacy_import(store)
    import.update_columns(owner_id: 0)

    expect { run! }.to output(/1 orphaned import/).to_stdout

    expect(import.reload.store).to eq(store)
  end

  it 'is idempotent' do
    legacy_import(seller)
    run!

    expect { run! }.to output(/nothing to do/).to_stdout
  end
end
