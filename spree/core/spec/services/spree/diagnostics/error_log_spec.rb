require 'spec_helper'

RSpec.describe Spree::Diagnostics::ErrorLog do
  let(:cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:spree_root) { Gem.loaded_specs['spree_core'].full_gem_path }
  let(:error) do
    RuntimeError.new('could not charge jane@example.com').tap do |error|
      error.set_backtrace(["#{spree_root}/app/workflows/spree/carts/complete.rb:162:in 'call'",
                           Rails.root.join("app/services/acme/checkout.rb:10:in 'run'").to_s,
                           Rails.root.join("app/controllers/acme_controller.rb:3:in 'create'").to_s])
    end
  end

  before do
    allow(Rails).to receive(:cache).and_return(cache)
    described_class.instance_variable_set(:@roots, nil)
  end

  after { described_class.instance_variable_set(:@roots, nil) }

  def report(error, source: 'spree.checkout', context: {})
    described_class.new.report(error, handled: true, severity: :warning, context: context, source: source)
  end

  it 'keeps the class and Spree frames, never the message' do
    report(error)

    entry = described_class.entries.sole
    expect(entry).to include(error_class: 'RuntimeError', source: 'spree.checkout', count: 1)
    expect(entry[:frames]).to eq(["spree_core-#{Spree.version}/app/workflows/spree/carts/complete.rb:162", 'app/[redacted]'])
    expect(cache.read(described_class::CACHE_KEY).to_s).not_to include('jane', 'acme')
  end

  it 'groups repeats of the same error' do
    2.times { report(error) }

    expect(described_class.entries.sole[:count]).to eq(2)
  end

  it "ignores errors that aren't Spree's" do
    error.set_backtrace([Rails.root.join("app/services/acme/checkout.rb:10:in 'run'").to_s])

    report(error, source: 'application.action_dispatch')

    expect(described_class.entries).to be_empty
  end

  it 'keeps a library error that Spree led to, with the Spree frame' do
    library_root = Gem.loaded_specs['activerecord'].full_gem_path
    error.set_backtrace(["#{library_root}/lib/active_record/validations.rb:84:in 'save!'",
                         "#{spree_root}/app/workflows/spree/carts/complete.rb:162:in 'call'"])

    report(error, source: 'application.action_dispatch')

    expect(described_class.entries.sole[:frames]).to eq(
      ["activerecord-#{Gem.loaded_specs['activerecord'].version}/lib/active_record/validations.rb:84",
       "spree_core-#{Spree.version}/app/workflows/spree/carts/complete.rb:162"]
    )
  end

  it 'ignores refused requests, which Rails answers with a 4xx' do
    invalid = ActiveRecord::RecordInvalid.new.tap { |e| e.set_backtrace(error.backtrace) }

    report(invalid, source: 'spree.api.v3')

    expect(described_class.entries).to be_empty
  end

  it "leaves the merchant's own errors alone, though Spree's middleware is on the stack" do
    error.set_backtrace(["#{Rails.root.join('app/controllers/acme_controller.rb')}:3:in 'create'",
                         "#{spree_root}/lib/spree/core/middleware.rb:10:in 'call'"])

    report(error, source: 'application.action_dispatch')

    expect(described_class.entries).to be_empty
  end

  it 'names no private gem' do
    library = Gem.loaded_specs['activerecord']
    allow(Spree::Diagnostics::Stack).to receive(:public_gem?).and_call_original
    allow(Spree::Diagnostics::Stack).to receive(:public_gem?).with(library).and_return(false)
    error.set_backtrace(["#{library.full_gem_path}/lib/active_record/validations.rb:84:in 'save!'",
                         "#{spree_root}/app/workflows/spree/carts/complete.rb:162:in 'call'"])

    report(error)

    expect(described_class.entries.sole[:frames].first).to eq('gem/[redacted]')
  end

  it 'does not call itself when the cache reports its own failure' do
    allow(cache).to receive(:read) do
      Rails.error.report(RuntimeError.new('cache down').tap { |e| e.set_backtrace(error.backtrace) }, source: 'spree.cache')
      nil
    end

    expect { report(error) }.not_to raise_error
    expect(cache).to have_received(:read).once
  end

  it 'does not recurse when every cache call reports its own failure' do
    failure = -> { Rails.error.report(RuntimeError.new('cache down').tap { |e| e.set_backtrace(error.backtrace) }, source: 'spree.cache') }
    allow(cache).to receive(:read) { failure.call && nil }
    allow(cache).to receive(:write) { failure.call && nil }

    expect { report(error) }.not_to raise_error
    expect(cache).to have_received(:read).once
    expect(cache).to have_received(:write).once
  end

  it 'keeps errors raised inside Spree whatever their source' do
    report(error, source: nil)

    expect(described_class.entries.size).to eq(1)
  end

  it 'records the request ID' do
    controller = double(request: double(request_id: 'req-123'))

    report(error, context: { controller: controller })

    expect(described_class.entries.sole[:request_id]).to eq('req-123')
  end

  it 'keeps only the most recent entries' do
    stub_const("#{described_class}::LIMIT", 2)

    3.times do |index|
      error = StandardError.new.tap { |e| e.set_backtrace(["#{spree_root}/app/models/spree/order.rb:#{index}:in 'x'"]) }
      travel_to(index.minutes.from_now) { report(error) }
    end

    expect(described_class.entries.map { |entry| entry[:frames].first }).to eq(
      ["spree_core-#{Spree.version}/app/models/spree/order.rb:2", "spree_core-#{Spree.version}/app/models/spree/order.rb:1"]
    )
  end

  it 'is subscribed to the Rails error reporter' do
    Rails.error.report(error, source: 'spree.checkout')

    expect(described_class.entries.size).to eq(1)
  end
end
