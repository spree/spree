require 'spec_helper'

RSpec.describe Spree::Api::Middleware::NoIndex do
  let(:status) { 200 }
  let(:app) { ->(_env) { [status, { 'content-type' => 'application/json' }, ['{}']] } }
  let(:middleware) { described_class.new(app) }

  it 'tells search engines not to index an API response' do
    _status, headers, _body = middleware.call('PATH_INFO' => '/api/v3/store/products')

    expect(headers['x-robots-tag']).to eq('noindex, nofollow')
  end

  context 'when the response is an error' do
    let(:status) { 404 }

    it 'marks it all the same' do
      _status, headers, _body = middleware.call('PATH_INFO' => '/api/v3/nothing-here')

      expect(headers['x-robots-tag']).to eq('noindex, nofollow')
    end
  end

  it 'leaves responses outside the API alone' do
    _status, headers, _body = middleware.call('PATH_INFO' => '/products/shirt')

    expect(headers).not_to have_key('x-robots-tag')
  end
end
