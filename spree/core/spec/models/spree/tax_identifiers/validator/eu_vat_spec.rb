require 'spec_helper'

RSpec.describe Spree::TaxIdentifiers::Validator::EuVat do
  describe '.valid_format?' do
    it 'accepts a well-formed number from every member state it can check' do
      # One per checksum algorithm family, so a regression names the country.
      %w[
        DE100000008
        ATU13585627
        IE6388047V
        FR32123456789
        NL123456782B12
        IT00743110157
        ES54362315K
        BE0776091951
        PL5260001246
        SE556188840401
      ].each do |number|
        expect(described_class.valid_format?(number)).to be(true), "expected #{number} to be accepted"
      end
    end

    it 'rejects a number whose check digit is wrong' do
      # DE100000008 with its last digit changed — right length, right country,
      # right shape, and still not a number anyone was issued.
      expect(described_class.valid_format?('DE100000009')).to be(false)
      expect(described_class.valid_format?('ATU13585628')).to be(false)
    end

    it 'rejects a number that is the wrong length for its country' do
      expect(described_class.valid_format?('DE10000000')).to be(false)
    end

    it 'accepts a member state whose check digit no algorithm covers' do
      # Czech and Latvian numbers get syntax alone. Turning away a real business
      # to catch a typo is the more expensive mistake, so these must pass.
      expect(described_class.valid_format?('CZ25123891')).to be(true)
      expect(described_class.valid_format?('LV40003009497')).to be(true)
    end

    # Greece is the one member state whose VAT prefix is not its ISO code: it
    # issues EL numbers while its ISO code is GR. Matching the prefix against a
    # list of ISO codes refuses every Greek business.
    it 'accepts a Greek number, which is prefixed EL rather than GR' do
      expect(described_class.valid_format?('EL094014201')).to be(true)
    end

    it 'rejects a Greek number spelled with its ISO code' do
      # No such registration exists — GR is not a VAT prefix.
      expect(described_class.valid_format?('GR094014201')).to be(false)
    end

    it 'accepts a Northern Ireland number' do
      # XI keeps EU VAT treatment for goods under the Windsor Framework.
      expect(described_class.valid_format?('XI123456782')).to be(true)
    end

    it 'rejects a number from outside the EU VAT area' do
      # Great Britain left it; Switzerland was never in it. Both are real
      # registrations, and both belong under a different kind.
      expect(described_class.valid_format?('GB123456782')).to be(false)
      expect(described_class.valid_format?('CHE116281710')).to be(false)
    end

    it 'rejects a value that is not a VAT number at all' do
      ['', '123456789', 'NOTAVAT', nil].each do |value|
        expect(described_class.valid_format?(value)).to be(false), "expected #{value.inspect} to be rejected"
      end
    end
  end

  describe '.checks_registry?' do
    it 'is false, because core asks no registry' do
      expect(described_class.checks_registry?).to be(false)
    end
  end
end
