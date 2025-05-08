require 'spec_helper'

describe 'Errors', type: :request do
  context 'with code parameter' do
    it 'renders 404 template for code 404' do
      get '/errors?code=404'

      expect(response.status).to eq(404)
      expect(response).to render_template('spree/errors/404')
    end

    it 'renders 500 template for code 500' do
      get '/errors?code=500'

      expect(response.status).to eq(500)
      expect(response).to render_template('spree/errors/500')
    end

    it 'renders 403 template for code 403' do
      get '/errors?code=403'

      expect(response.status).to eq(403)
      expect(response).to render_template('spree/errors/403')
    end

    it 'renders 422 template for code 422' do
      get '/errors?code=422'

      expect(response.status).to eq(422)
      expect(response).to render_template('spree/errors/422')
    end

    it 'renders 503 template for code 503' do
      get '/errors?code=503'

      expect(response.status).to eq(503)
      expect(response).to render_template('spree/errors/503')
    end
  end

  context 'with path-based code' do
    it 'extracts code from path and renders correct template' do
      get '/errors/403'

      expect(response).to render_template('spree/errors/403')
      expect(response.status).to eq(403)
    end
  end

  context 'with invalid code' do
    it 'falls back to 500 for non-HTTP status code' do
      get '/errors/999'

      expect(response).to render_template('spree/errors/500')
      expect(response.status).to eq(500)
    end

    it 'falls back to 500 for non-error HTTP status code' do
      get '/errors/200'

      expect(response).to render_template('spree/errors/500')
      expect(response.status).to eq(500)
    end

    it 'falls back to 500 for non-numeric code' do
      get '/errors/error'
      expect(response).to render_template('spree/errors/500')
      expect(response.status).to eq(500)
    end
  end

  context 'without any code' do
    it 'defaults to 500 when no code is provided' do
      get '/errors'
      expect(response).to render_template('spree/errors/500')
      expect(response.status).to eq(500)
    end
  end
end
