require 'spec_helper'

RSpec.describe Spree::SearchProvider::RateLimited do
  def job_class_with_rate_limit_support
    Class.new(ActiveJob::Base) do
      class_attribute :declared_rate_limit

      def self.limits_rate(**options)
        self.declared_rate_limit = options
      end
    end
  end

  it 'caps index jobs per second across every store when a limit is set' do
    allow(Spree::Config).to receive(:search_index_rate_limit).and_return(10)
    job_class = job_class_with_rate_limit_support
    job_class.include(described_class)

    expect(job_class.declared_rate_limit).to eq(to: 10, per: 1.second, burst: 2, key: :global, group: 'spree_search_provider')
  end

  it 'leaves the jobs unlimited by default' do
    allow(Spree::Config).to receive(:search_index_rate_limit).and_return(0)
    job_class = job_class_with_rate_limit_support
    job_class.include(described_class)

    expect(job_class.declared_rate_limit).to be_nil
  end

  it 'explains how to fix an installed gem too old for the limit' do
    allow(Spree::Config).to receive(:search_index_rate_limit).and_return(10)
    allow(Gem.loaded_specs).to receive(:[]).and_call_original
    allow(Gem.loaded_specs).to receive(:[]).with('solid_queue-rate_limit').
      and_return(Gem::Specification.new { |spec| spec.version = '0.1.0' })

    expect { job_class_with_rate_limit_support.include(described_class) }.
      to raise_error(/solid_queue-rate_limit 0.2.0 or newer \(0.1.0 is installed\)/)
  end

  it 'does nothing without the solid_queue-rate_limit gem' do
    allow(Spree::Config).to receive(:search_index_rate_limit).and_return(10)

    expect { Class.new(ActiveJob::Base).include(described_class) }.not_to raise_error
  end
end
