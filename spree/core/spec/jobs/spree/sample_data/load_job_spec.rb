require 'spec_helper'

RSpec.describe Spree::SampleData::LoadJob, type: :job do
  it 'runs the sample data loader' do
    loader = class_double(Spree::SampleData::Loader, call: nil).as_stubbed_const

    described_class.perform_now

    expect(loader).to have_received(:call)
  end
end
