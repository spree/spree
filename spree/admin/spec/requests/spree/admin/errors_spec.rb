require 'spec_helper'

describe 'Errors', type: :request do
  context 'with code parameter' do
    it 'renders 404 template for code 404' do
      get '/admin/errors?code=404'

      expect(response.status).to eq(404)
      expect(response).to render_template('spree/admin/errors/404')
    end

    it 'renders 500 template for code 500' do
      get '/admin/errors?code=500'

      expect(response.status).to eq(500)
      expect(response).to render_template('spree/admin/errors/500')
    end

    it 'renders 403 template for code 403' do
      get '/admin/errors?code=403'

      expect(response.status).to eq(403)
      expect(response).to render_template('spree/admin/errors/403')
    end

    it 'renders 422 template for code 422' do
      get '/admin/errors?code=422'

      expect(response.status).to eq(422)
      expect(response).to render_template('spree/admin/errors/422')
    end

    it 'renders 503 template for code 503' do
      get '/admin/errors?code=503'

      expect(response.status).to eq(503)
      expect(response).to render_template('spree/admin/errors/503')
    end
  end

  context 'with path-based code' do
    it 'extracts code from path and renders correct template' do
      get '/admin/errors/403'

      expect(response).to render_template('spree/admin/errors/403')
      expect(response.status).to eq(403)
    end
  end

  context 'with invalid code' do
    it 'falls back to 500 for non-HTTP status code' do
      get '/admin/errors/999'

      expect(response).to render_template('spree/admin/errors/500')
      expect(response.status).to eq(500)
    end

    it 'falls back to 500 for non-error HTTP status code' do
      get '/admin/errors/200'
      expect(response).to render_template('spree/admin/errors/500')
      expect(response.status).to eq(500)
    end

    it 'falls back to 500 for non-numeric code' do
      get '/admin/errors/error'
      expect(response).to render_template('spree/admin/errors/500')
      expect(response.status).to eq(500)
    end
  end

  context 'without any code' do
    it 'defaults to 500 when no code is provided' do
      get '/admin/errors'
      expect(response).to render_template('spree/admin/errors/500')
      expect(response.status).to eq(500)
    end
  end
end
