require 'spec_helper'

describe Spree::Webhooks::Endpoints::MakeRequest do
  describe '#call' do
    subject { described_class.new(body: body, event: event, url: url).call }

    let(:event) { 'order.cancel' }
    let(:url) { 'http://google.com/' }
    let(:body) { { foo: :bar }.to_json }

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
          let(:uri) { URI(url) }
          let(:http) { Net::HTTP.new(uri.host, uri.port) }

          shared_examples 'makes the request without setting use_ssl' do
            it 'does not set use_ssl' do
              expect(Net::HTTP).to receive(:new).with(uri.host, uri.port).and_return(http)
              expect(http).to_not receive(:use_ssl=)
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

            it 'does set use_ssl' do
              expect(Net::HTTP).to receive(:new).and_return(http)
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

        context 'when request code_type is not Net::HTTPOK' do
          before do
            http_double = instance_double(Net::HTTP)
            allow(Net::HTTP).to receive(:new).and_return(http_double)
            allow(http_double).to(
              receive(:request).and_return(
                double(:request).tap do |request|
                  allow(request).to receive(:code_type).and_return(Net::HTTPClientError)
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

        context 'when request code_type is Net::HTTPOK' do
          it 'debug logs after the request and returns its value' do
            message = "[SPREE WEBHOOKS] 'order.cancel' success for URL 'http://google.com/'"
            expect(subject).to eq(Rails.logger.debug(message))
          end
        end
      end
    end
  end
end
