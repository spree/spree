module Spree
  class TestArgumentsJob < Spree::BaseJob
    def perform(serializer); end
  end
end

shared_examples 'an ActiveJob serializable hash' do
  it 'can be serialized by ActiveJob' do
    # It should fail if subject contains any custom instance (e.g Spree::Money)
    expect { Spree::TestArgumentsJob.perform_later(subject) }.not_to raise_error
    expect { Spree::TestArgumentsJob.perform_later(subject.merge(price: Spree::Money.new(0))) }.to(
      raise_error(ActiveJob::SerializationError)
    )
  end
end
