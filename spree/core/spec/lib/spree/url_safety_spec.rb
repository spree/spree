# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::UrlSafety do
  describe '.validate_url!' do
    context 'with public URLs' do
      it 'does not raise for public hostname' do
        allow(Resolv).to receive(:getaddresses).with('example.com').and_return(['93.184.216.34'])
        expect { described_class.validate_url!('https://example.com/webhook') }.not_to raise_error
      end
    end

    context 'with loopback addresses' do
      it 'raises SsrfError for 127.0.0.1' do
        allow(Resolv).to receive(:getaddresses).with('localhost').and_return(['127.0.0.1'])
        expect { described_class.validate_url!('http://localhost/test') }.to raise_error(Spree::UrlSafety::SsrfError)
      end

      it 'raises SsrfError for ::1' do
        allow(Resolv).to receive(:getaddresses).with('localhost').and_return(['::1'])
        expect { described_class.validate_url!('http://localhost/test') }.to raise_error(Spree::UrlSafety::SsrfError)
      end
    end

    context 'with private RFC 1918 ranges' do
      %w[10.0.0.1 172.16.0.1 192.168.1.1].each do |ip|
        it "raises SsrfError for #{ip}" do
          allow(Resolv).to receive(:getaddresses).with('internal.example.com').and_return([ip])
          expect { described_class.validate_url!('https://internal.example.com/hook') }.to raise_error(Spree::UrlSafety::SsrfError)
        end
      end
    end

    context 'with cloud metadata address' do
      it 'raises SsrfError for 169.254.169.254' do
        allow(Resolv).to receive(:getaddresses).with('metadata.example.com').and_return(['169.254.169.254'])
        expect { described_class.validate_url!('http://metadata.example.com/latest/') }.to raise_error(Spree::UrlSafety::SsrfError)
      end
    end

    context 'with 0.0.0.0 range' do
      it 'raises SsrfError for 0.0.0.0' do
        allow(Resolv).to receive(:getaddresses).with('zero.example.com').and_return(['0.0.0.0'])
        expect { described_class.validate_url!('http://zero.example.com/test') }.to raise_error(Spree::UrlSafety::SsrfError)
      end
    end

    context 'with IPv6 private ranges' do
      it 'raises SsrfError for fc00:: ULA' do
        allow(Resolv).to receive(:getaddresses).with('ipv6.example.com').and_return(['fc00::1'])
        expect { described_class.validate_url!('https://ipv6.example.com/hook') }.to raise_error(Spree::UrlSafety::SsrfError)
      end

      it 'raises SsrfError for fe80:: link-local' do
        allow(Resolv).to receive(:getaddresses).with('ipv6.example.com').and_return(['fe80::1'])
        expect { described_class.validate_url!('https://ipv6.example.com/hook') }.to raise_error(Spree::UrlSafety::SsrfError)
      end
    end

    context 'with mixed public and private resolution' do
      it 'raises SsrfError if any resolved IP is private' do
        allow(Resolv).to receive(:getaddresses).with('mixed.example.com').and_return(['93.184.216.34', '10.0.0.1'])
        expect { described_class.validate_url!('https://mixed.example.com/hook') }.to raise_error(Spree::UrlSafety::SsrfError)
      end
    end

    context 'with missing hostname' do
      it 'raises SsrfError for blank host' do
        expect { described_class.validate_url!('https:///path') }.to raise_error(Spree::UrlSafety::SsrfError, /missing hostname/)
      end
    end

    context 'with unresolvable hostname' do
      it 'raises SsrfError' do
        allow(Resolv).to receive(:getaddresses).with('nxdomain.example.com').and_return([])
        expect { described_class.validate_url!('https://nxdomain.example.com/hook') }.to raise_error(Spree::UrlSafety::SsrfError, /Could not resolve/)
      end
    end
  end
end
