require 'spec_helper'
require 'rake'

describe 'spree:price_history:prune' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:price_history:prune' }

  # Rake's registry is global and shared with every other task spec. Declaring
  # the :environment prerequisite unconditionally CLEARS that registry, which
  # silently un-defines tasks that sibling specs loaded at file scope — so
  # declare it only when nothing already has, and re-load this task per example
  # so it survives whatever else the run does.
  # Guarded on both counts. Rake's registry is process-global: redefining a
  # task APPENDS its action, so an unguarded load runs the body one more time
  # per example, and `define_task(:environment)` unguarded would clear tasks
  # that sibling specs loaded at file scope.
  before do
    unless Rake::Task.task_defined?(task_name)
      load Spree::Core::Engine.root.join('lib', 'tasks', 'price_history.rake')
    end
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    subject.reenable
  end

  let(:store) { @default_store }
  let(:variant) { create(:variant) }
  let(:price) { variant.prices.first }

  def history_at(recorded_at)
    create(:price_history, price: price).
      tap { |record| record.update_columns(recorded_at: recorded_at) }
  end

  it 'keeps what the retention window still covers' do
    recent = history_at(3.days.ago)

    silence_stream(STDOUT) { subject.invoke }

    expect(Spree::PriceHistory.exists?(recent.id)).to be(true)
  end

  it 'prunes what has aged out of it' do
    stale = history_at(90.days.ago)

    silence_stream(STDOUT) { subject.invoke }

    expect(Spree::PriceHistory.exists?(stale.id)).to be(false)
  end

  # A store that records history for longer keeps it for longer, which is the
  # point of moving the setting off the global config.
  it "honours a store's own retention window" do
    stale = history_at(60.days.ago)
    stub_store_preferences(store, price_history_retention_days: 365)

    silence_stream(STDOUT) { subject.invoke }

    expect(Spree::PriceHistory.exists?(stale.id)).to be(true)
  end

  it 'reaches rows whose variant was soft-deleted' do
    stale = history_at(90.days.ago)
    variant.destroy

    silence_stream(STDOUT) { subject.invoke }

    expect(Spree::PriceHistory.exists?(stale.id)).to be(false)
  end

  # Nothing owns these any more, so no store's query would find them and they
  # would otherwise outlive every retention window there is.
  it 'sweeps rows whose variant is gone entirely' do
    orphan = history_at(90.days.ago)
    Spree::Variant.with_deleted.where(id: variant.id).delete_all

    silence_stream(STDOUT) { subject.invoke }

    expect(Spree::PriceHistory.exists?(orphan.id)).to be(false)
  end
end
