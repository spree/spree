require 'spec_helper'
require 'spree/api/openapi/path_sorter'

RSpec.describe Spree::Api::OpenAPI::PathSorter do
  let(:yaml) do
    <<~YAML
      openapi: 3.0.3
      paths:
        "/api/v3/store/wishlists":
          get:
            tags:
            - Wishlists
        "/api/v3/store/companies":
          get:
            tags:
            - Companies
        "/api/v3/store/auth/login":
          post:
            tags:
            - Authentication
        "/api/v3/store/carts":
          get:
            tags:
            - Carts
          post:
            tags:
            - Carts
      tags:
      - name: Wishlists
        description: Customer wishlists
      - name: Authentication
        description: Customer authentication (login, logout, token
          refresh)
      - name: Carts
      components: {}
    YAML
  end

  let(:sorted) { YAML.safe_load(described_class.sort_text(yaml)) }

  it 'orders paths alphabetically by tag, Authentication first' do
    expect(sorted['paths'].keys).to eq(%w[
      /api/v3/store/auth/login
      /api/v3/store/carts
      /api/v3/store/companies
      /api/v3/store/wishlists
    ])
  end

  it 'rewrites the tags block in the same order, adding undeclared tags' do
    expect(sorted['tags']).to eq([
      { 'name' => 'Authentication', 'description' => 'Customer authentication (login, logout, token refresh)' },
      { 'name' => 'Carts' },
      { 'name' => 'Companies' },
      { 'name' => 'Wishlists', 'description' => 'Customer wishlists' }
    ])
  end

  it 'keeps everything else intact' do
    expect(sorted['paths']['/api/v3/store/carts'].keys).to eq(%w[get post])
    expect(sorted['components']).to eq({})
  end

  it 'is idempotent' do
    once = described_class.sort_text(yaml)
    expect(described_class.sort_text(once)).to eq(once)
  end
end
