require 'spec_helper'

# Emailed and bookmarked download URLs outlive the 6.0 rename, so both paths
# must reach the controller until the legacy one is dropped in 6.1.
RSpec.describe 'digital link download routing', type: :routing do
  routes { Spree::Core::Engine.routes }

  it 'routes the canonical digital_links path' do
    expect(get: '/api/v3/store/digital_links/abc123').to route_to(
      controller: 'spree/api/v3/store/digital_links',
      action: 'show',
      token: 'abc123',
      format: 'json'
    )
  end

  it 'routes the legacy digitals path to the same action' do
    expect(get: '/api/v3/store/digitals/abc123').to route_to(
      controller: 'spree/api/v3/store/digital_links',
      action: 'show',
      token: 'abc123',
      format: 'json'
    )
  end
end
