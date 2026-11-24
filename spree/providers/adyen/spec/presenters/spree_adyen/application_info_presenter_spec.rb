require 'spec_helper'

RSpec.describe SpreeAdyen::ApplicationInfoPresenter do
  it 'names Spree and the gem' do
    info = described_class.new.to_h[:applicationInfo]

    expect(info[:externalPlatform]).to include(name: 'Spree Commerce', version: Spree.version)
    expect(info[:merchantApplication]).to include(name: 'spree_adyen', version: Spree.version)
  end
end
