require 'spec_helper'

describe Spree::Webhooks::Endpoints::MakeRequest do
  describe '#call' do
    subject { described_class.call(body: body, url: url) }

    let(:url) { 'https://google.com/' }
    let(:body) { { foo: :bar }.to_json }

    shared_examples 'returns a failure without making a request' do
      it 'does not instantiate a Net::HTTP::Post to make a request' do
        expect(Net::HTTP::Post).not_to receive(:new)
        subject
      end

      it 'returns a failure' do
        expect(subject.success).to eq(false)
      end

      it 'returns false wrapped into a failure' do
        expect(subject.value).to eq(false)
      end
    end

    context 'without an empty string as body' do
      let(:body) { '' }

      include_examples 'returns a failure without making a request'
    end

    context 'with a valid body' do
      context 'without a valid URL' do
        let(:url) { '' }

        include_examples 'returns a failure without making a request'
      end

      context 'with a valid URL' do
        let(:headers) { { 'Content-Type' => 'application/json' } }

        before { stub_request(:post, url) }

        it 'makes a post HTTP request to the given url and body' do
          subject
          expect(WebMock).to(
            have_requested(:post, url).with(body: body, headers: headers).once
          )
        end

        context 'when request code_type is Net::HTTPOK' do
          it 'returns true wrapped into a success' do
            expect(subject.value).to eq(true)
          end
        end

        context 'when request code_type is not Net::HTTPOK' do
          before do
            http_double = instance_double(Net::HTTP)
            expect(Net::HTTP).to receive(:new).and_return(http_double)
            expect(http_double).to receive(:use_ssl=)
            expect(http_double).to(
              receive(:request).and_return(
                double(:request).tap do |request|
                  expect(request).to receive(:code_type).and_return(Net::HTTPClientError)
                end
              )
            )
          end

          it 'returns a success' do
            expect(subject.success).to eq(true)
          end

          it 'returns true wrapped into a success' do
            expect(subject.value).to eq(false)
          end
        end
      end
    end
  end
end
