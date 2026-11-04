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

  it "defines the extension's task" do
    described_class.new(engine: 'MyExtension::Engine', out: '../my-extension-sdk/src/types')

    expect(Rake::Task.task_defined?('spree:sdk:serializer_types')).to be(true)
  end

  it 'asks for the test app when it is missing' do
    described_class.new(engine: 'MyExtension::Engine', out: 'types', dummy: 'spec/missing/config/environment.rb')

    expect { Rake::Task['spree:sdk:serializer_types'].invoke }
      .to raise_error(SystemExit).and output(/bundle exec rake test_app/).to_stderr
  end
end
