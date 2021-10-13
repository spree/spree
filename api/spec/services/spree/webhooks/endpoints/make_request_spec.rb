require 'spec_helper'

describe Spree::Webhooks::Endpoints::MakeRequest do
  describe '#call' do
    subject { described_class.new(body: body, event: event, url: url).call }

    let(:event) { 'order.cancel' }
    let(:url) { 'http://google.com/' }
    let(:body) { { foo: :bar }.to_json }
    let(:uri) { URI(url) }
    let(:http) { Net::HTTP.new(uri.host, uri.port) }

    shared_examples 'returns nil without making a request' do
      it 'does not instantiate Net::HTTP::Post to make a request' do
        expect(Net::HTTP::Post).not_to receive(:new)
        subject
      end

      it { expect(subject).to eq(nil) }
    end

    context 'with an unexpected body' do
      let(:body) { '' }

      include_examples 'returns nil without making a request'
    end

    context 'with an expected body' do
      context 'without a valid URL' do
        let(:url) { '' }

        it 'debug logs before the request' do
          allow(Rails.logger).to receive(:warn)
          subject
          message = "[SPREE WEBHOOKS] 'order.cancel' can not make a request to ''"
          expect(Rails.logger).to have_received(:warn).with(message)
        end

        include_examples 'returns nil without making a request'
      end

      context 'with a valid URL' do
        let(:headers) { { 'Content-Type' => 'application/json' } }

        before { stub_request(:post, url) }

        it 'debug logs before the request' do
          allow(Rails.logger).to receive(:debug)
          subject
          message_fst = "[SPREE WEBHOOKS] 'order.cancel' sending to 'http://google.com/'"
          message_snd = "[SPREE WEBHOOKS] 'order.cancel' body: #{body}"
          expect(Rails.logger).to have_received(:debug).with(message_fst)
          expect(Rails.logger).to have_received(:debug).with(message_snd)
        end

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

        describe 'setting the read_timeout through the SPREE_WEBHOOKS_TIMEOUT env var' do
          context 'without a SPREE_WEBHOOKS_TIMEOUT env var' do
            before { ENV['SPREE_WEBHOOKS_TIMEOUT'] = nil }

            it 'does not set Net::HTTP#read_timeout=' do
              expect(http).not_to receive(:read_timeout=)
              subject
            end
          end

          context 'with a SPREE_WEBHOOKS_TIMEOUT env var' do
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

        describe 'handling the request response status code' do
          let(:http_double) { instance_double(Net::HTTP) }

          context 'when the request status code is not 2xx' do
            before do
              allow(Net::HTTP).to receive(:new).and_return(http_double)
              allow(http_double).to(
                receive(:request).and_return(
                  double(:request).tap do |request|
                    allow(request).to receive(:code).and_return('304')
                  end
                )
              )
            end

            it 'warn logs after the request' do
              allow(Rails.logger).to receive(:warn)
              subject
              message = "[SPREE WEBHOOKS] 'order.cancel' failed for 'http://google.com/'"
              expect(Rails.logger).to have_received(:warn).with(message)
            end

            it { expect(subject).to eq(nil) }
          end

          context 'when the request raises a SocketError exception' do
            before do
              allow(Net::HTTP).to receive(:new).and_return(http_double)
              allow(http_double).to receive(:request) do
                raise SocketError
              end
            end

            it { expect(subject).to eq(nil) }
          end

          context 'when the request raises a Net::ReadTimeout exception' do
            before do
              allow(Net::HTTP).to receive(:new).and_return(http_double)
              allow(http_double).to receive(:request) do
                raise Net::ReadTimeout
              end
            end

            it { expect(subject).to eq(nil) }
          end

          context 'when request status code is 2xx' do
            it 'debug logs after the request and returns its value' do
              message = "[SPREE WEBHOOKS] 'order.cancel' success for URL 'http://google.com/'"
              expect(subject).to eq(Rails.logger.debug(message))
            end
          end
        end
      end
    end
  end
end
