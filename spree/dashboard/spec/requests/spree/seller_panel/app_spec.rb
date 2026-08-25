require 'spec_helper'

RSpec.describe 'Hosted seller panel', type: :request do
  let(:dist) { Dir.mktmpdir }

  before do
    File.write(File.join(dist, 'index.html'), '<html>seller panel shell</html>')
    FileUtils.mkdir_p(File.join(dist, 'assets'))
    File.write(File.join(dist, 'assets', 'panel-abc123.js'), 'console.log("panel")')
  end

  after do
    FileUtils.remove_entry(dist)
    Spree::Dashboard.seller_panel_dist_path = nil
    Spree::Dashboard.dist_path = nil
  end

  # A marketplace that runs no seller panel serves nothing, rather than an
  # empty shell that looks broken.
  context 'when no bundle is configured' do
    it 'returns 404' do
      get '/sellers'
      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when a bundle is configured' do
    before { Spree::Dashboard.seller_panel_dist_path = dist }

    it 'serves the shell at the mount root' do
      get '/sellers'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('seller panel shell')
      expect(response.headers['Cache-Control']).to eq('no-cache')
    end

    # Deep links are the point: an invitation lands on
    # /sellers/accept-invitation/... and the SPA routes it client-side.
    it 'falls back to the shell for client-side routes' do
      get '/sellers/accept-invitation/inv_abc'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('seller panel shell')
    end

    it 'serves hashed assets as immutable' do
      get '/sellers/assets/panel-abc123.js'

      expect(response).to have_http_status(:ok)
      expect(response.headers['Cache-Control']).to include('immutable')
    end

    it 'refuses to escape the bundle directory' do
      get '/sellers/assets/%2e%2e/%2e%2e/config/database.yml'

      # Either refused outright or answered with the SPA shell — never the file.
      expect(response.body).not_to include('adapter:')
    end

    # The two panels are separate apps: configuring one must not serve the
    # other, or a marketplace with no seller panel would hand sellers the
    # operator's dashboard.
    it 'does not serve the dashboard bundle' do
      Spree::Dashboard.seller_panel_dist_path = nil
      Spree::Dashboard.dist_path = dist

      get '/sellers'

      expect(response).to have_http_status(:not_found)
    end
  end
end
