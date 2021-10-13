require 'spec_helper'

describe Spree::Webhooks::Endpoints::MakeRequest do
  let(:body) { { data: [{}] }.to_json }
  let(:url) { 'google.com' }

  describe '#failed_request?' do
    subject { described_class.new(body: body, url: url).failed_request? }

    before { stub_request(:post, url) }

    let(:headers) { { 'Content-Type' => 'application/json' } }
    let(:http) { Net::HTTP.new(uri.host, uri.port) }
    let(:http_double) { instance_double(Net::HTTP) }
    let(:uri) { URI(url) }
    let(:url) { 'http://google.com/' }

    describe 'ssl usage' do
      shared_examples 'makes the request without setting use_ssl' do
        it 'does not set use_ssl' do
          allow(Net::HTTP).to receive(:new).with(uri.host, uri.port).and_return(http)
          expect(http).not_to receive(:use_ssl=)
          subject
        end

        it 'makes a post HTTP request to the given url and body' do
          subject
          expect(WebMock).to have_requested(:post, url).with(body: body, headers: headers).once
        end
      end

      context 'with development environment' do
        before { allow(Rails).to receive_message_chain(:env, :development?).and_return(true) }

        include_examples 'makes the request without setting use_ssl'
      end

      context 'with test environment' do
        include_examples 'makes the request without setting use_ssl'
      end

      context 'without test and/or development environment' do
        before do
          allow(Rails).to receive_message_chain(:env, :development?).and_return(false)
          allow(Rails).to receive_message_chain(:env, :test?).and_return(false)
        end

        let(:url) { 'http://google.com/' }

        it 'sets use_ssl' do
          allow(Net::HTTP).to receive(:new).and_return(http)
          expect(http).to receive(:use_ssl=).with(true)
          subject
        end

        it 'makes a post HTTP request to the given url and body' do
          allow(Net::HTTP).to receive(:new).and_return(http)
          allow(http).to receive(:use_ssl=).with(true)
          subject
          expect(WebMock).to have_requested(:post, url).with(body: body, headers: headers).once
        end
      end
    end

    describe 'setting read_timeout with SPREE_WEBHOOKS_TIMEOUT' do
      context 'without SPREE_WEBHOOKS_TIMEOUT' do
        before { ENV['SPREE_WEBHOOKS_TIMEOUT'] = nil }

        it 'does not set Net::HTTP#read_timeout=' do
          expect(http).not_to receive(:read_timeout=)
          subject
        end
      end

      context 'with SPREE_WEBHOOKS_TIMEOUT' do
        before do
          ENV['SPREE_WEBHOOKS_TIMEOUT'] = spree_webhooks_timeout.to_s
          allow(Net::HTTP).to receive(:new).with(uri.host, uri.port).and_return(http)
        end

        after { ENV['SPREE_WEBHOOKS_TIMEOUT'] = nil }

        let(:spree_webhooks_timeout) { 15 } # time in seconds

        it 'sets Net::HTTP#read_timeout= to the integer value of SPREE_WEBHOOKS_TIMEOUT' do
          expect(http).to receive(:read_timeout=).with(spree_webhooks_timeout)
          subject
        end
      end
    end

    context 'when the request raises a SocketError exception' do
      before do
        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:request) { raise SocketError }
      end

      it { expect(subject).to eq(true) }
    end

    context 'when the request raises a Net::ReadTimeout exception' do
      before do
        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:request) { raise Net::ReadTimeout }
      end

      it { expect(subject).to eq(true) }
    end

    context 'when the request status code is not 2xx' do
      before do
        allow(Net::HTTP).to receive(:new).and_return(http_double)
        allow(http_double).to receive(:request).and_return(request_double)
        allow(request_double).to receive(:code).and_return('304')
      end

      let(:request_double) { double }

      it { expect(subject).to eq(true) }
    end

    context 'when request status code is 2xx' do
      it { expect(subject).to eq(false) }
    end
  end

  describe '#unprocessable_uri?' do
    subject { described_class.new(body: body, url: url) }

    before { allow(subject).to receive(:URI).with(url).and_return(uri) }

    shared_examples 'detects an unprocessable uri' do
      it { expect(subject.unprocessable_uri?).to eq(true) }
    end

    let(:uri) { URI(url) }

    context 'uri with path ""' do
      before { uri.path = '' }

      include_examples 'detects an unprocessable uri'
    end

    context 'uri with path "" and without host' do
      before do
        uri.path = ''
        uri.host = nil
      end

      include_examples 'detects an unprocessable uri'
    end

    context 'uri with path "", without host and without port' do
      before do
        uri.path = ''
        uri.host = nil
        uri.port = nil
      end

      include_examples 'detects an unprocessable uri'
    end
  end
end
