require 'spec_helper'

RSpec.describe 'Hosted React Dashboard', type: :request do
  let(:dist) { Dir.mktmpdir }

  before do
    File.write(File.join(dist, 'index.html'), '<html>dashboard shell</html>')
    FileUtils.mkdir_p(File.join(dist, 'assets'))
    File.write(File.join(dist, 'assets', 'app-abc123.js'), 'console.log("bundle")')
    File.write(File.join(dist, 'favicon.svg'), '<svg/>')
  end

  after do
    FileUtils.remove_entry(dist)
    Spree::Dashboard.dist_path = nil
  end

  context 'when dist_path is not configured' do
    it 'returns 404' do
      get '/dashboard'
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when dist_path is configured' do
    before { Spree::Dashboard.dist_path = dist }

    it 'serves index.html at the root with no-cache' do
      get '/dashboard'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('dashboard shell')
      expect(response.headers['Cache-Control']).to eq('no-cache')
    end

    it 'serves hashed assets as immutable' do
      get '/dashboard/assets/app-abc123.js'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('bundle')
      # Rails normalizes Cache-Control directive order — assert on parts.
      expect(response.headers['Cache-Control']).to include('max-age=31536000')
      expect(response.headers['Cache-Control']).to include('immutable')
    end

    it 'serves non-hashed root files with a short cache' do
      get '/dashboard/favicon.svg'

      expect(response).to have_http_status(:ok)
      expect(response.headers['Cache-Control']).to include('max-age=3600')
    end

    it 'falls back to index.html for SPA routes' do
      get '/dashboard/store_abc/orders'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('dashboard shell')
      expect(response.headers['Cache-Control']).to eq('no-cache')
    end

    it 'does not serve files outside the dist directory' do
      secret = File.expand_path(File.join(dist, '..', "spree-secret-#{Process.pid}.txt"))
      File.write(secret, 'top secret')

      get "/dashboard/%2e%2e/#{File.basename(secret)}"

      expect(response.body).not_to include('top secret')
    ensure
      FileUtils.rm_f(secret)
    end

    it 'reads the dist path from the environment when unset' do
      Spree::Dashboard.dist_path = nil
      ENV['SPREE_DASHBOARD_DIST_PATH'] = dist

      get '/dashboard'
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('dashboard shell')
    ensure
      ENV.delete('SPREE_DASHBOARD_DIST_PATH')
    end

    it 'returns 404 when the configured directory does not exist' do
      Spree::Dashboard.dist_path = File.join(dist, 'missing')

      get '/dashboard'
      expect(response).to have_http_status(:not_found)
    end
  end
end
