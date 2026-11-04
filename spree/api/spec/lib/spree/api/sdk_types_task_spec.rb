require 'spec_helper'
require 'spree/api/sdk_types_task'

RSpec.describe Spree::Api::SdkTypesTask do
  around do |example|
    application = Rake.application
    Rake.application = Rake::Application.new
    example.run
  ensure
    Rake.application = application
  end

  it 'defines the task once, however many times it is set up' do
    described_class.new
    described_class.new

    expect(Rake::Task.task_defined?('spree:sdk:serializer_types')).to be(true)
    expect(Rake::Task['spree:sdk:serializer_types'].actions.size).to eq(1)
  end

  it 'asks where to write' do
    described_class.new
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('OUT').and_return(nil)

    expect { Rake::Task['spree:sdk:serializer_types'].invoke }
      .to raise_error(SystemExit).and output(/Pass OUT/).to_stderr
  end

  it 'asks for the test app when it is missing' do
    described_class.new(out: 'types', dummy: 'spec/missing/config/environment.rb')

    expect { Rake::Task['spree:sdk:serializer_types'].invoke }
      .to raise_error(SystemExit).and output(/bundle exec rake test_app/).to_stderr
  end

  it 'finds the engine whose root is the current folder' do
    Dir.chdir(Spree::Api::Engine.root) do
      expect(described_class.owner_here).to eq(Spree::Api::Engine)
    end
  end
end
