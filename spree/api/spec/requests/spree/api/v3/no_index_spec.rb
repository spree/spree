require 'spec_helper'

# No API response belongs in a search index: Store API JSON would compete
# with the storefront's pages, and tokened URLs travel in emails.
RSpec.describe 'API responses and search engines', type: :request do
  include_context 'API v3 Store'

  it 'marks a public Store API response noindex' do
    get '/api/v3/store/products', headers: api_key_headers

    expect(response).to have_http_status(:ok)
    expect(response.headers['X-Robots-Tag']).to eq('noindex, nofollow')
  end

  it 'marks a refused Admin API response noindex' do
    get '/api/v3/admin/products'

    expect(response).to have_http_status(:unauthorized)
    expect(response.headers['X-Robots-Tag']).to eq('noindex, nofollow')
  end

  it 'marks the 404 for an unknown API path noindex' do
    get '/api/v3/nothing-here'

    expect(response).to have_http_status(:not_found)
    expect(response.headers['X-Robots-Tag']).to eq('noindex, nofollow')
  end
end
