require 'spec_helper'

RSpec.describe Spree::SampleData::LoadJob, type: :job do
  let!(:loader) { class_double(Spree::SampleData::Loader, call: nil).as_stubbed_const }

  it 'loads into the default store when no store is given' do
    described_class.perform_now

    expect(loader).to have_received(:call).with(no_args)
  end

  it 'loads into the given store' do
    store = create(:store)

    described_class.perform_now(store.id)

    expect(loader).to have_received(:call).with(store: store)
  end

  it 'skips a store that no longer exists' do
    described_class.perform_now(0)

    expect(loader).not_to have_received(:call)
  end
end
