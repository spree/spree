require 'spec_helper'

describe Spree::Addresses::PhoneValidator do
  subject { described_class.new }

  shared_examples 'does not add a phone error' do
    it 'does not add an error' do
      subject.validate(address)
      expect(address.errors[:phone]).to be_empty
    end
  end

  before do
    Spree::Config[:address_requires_phone] = true
  end

  describe '#validate' do
    context 'when no phone is provided' do
      let(:address) { create(:address, phone: nil) }

      before do
        Spree::Config[:address_requires_phone] = false
      end

      it_behaves_like 'does not add a phone error'
    end

    context 'when no country is provided' do
      let(:address) { build_stubbed(:address, phone: '2025550123', country: nil) }

      before do
        Spree::Config[:address_requires_phone] = false
      end

      it_behaves_like 'does not add a phone error'
    end

    context 'when no country iso is provided' do
      let(:address) { build_stubbed(:address, phone: '2025550123') }

      before do
        Spree::Config[:address_requires_phone] = false
        address.country.iso = nil
      end

      it_behaves_like 'does not add a phone error'
    end

    context 'when phone is provided' do
      context 'and country is US' do
        context 'and phone is valid' do
          let(:address) { create(:address, phone: phone) }

          context 'without prefix' do
            let(:phone) { '2025550123' }

            it_behaves_like 'does not add a phone error'
          end

          context 'and has prefix with plus sign' do
            let(:phone) { '+12025550123' }

            it_behaves_like 'does not add a phone error'
          end

          context 'and has prefix without plus sign' do
            let(:phone) { '12025550123' }

            it_behaves_like 'does not add a phone error'
          end

          context 'and has dashes' do
            let(:phone) { '202-555-0123' }

            it_behaves_like 'does not add a phone error'
          end

          context 'and has dashes and prefix' do
            let(:phone) { '+1202-555-0123' }

            it_behaves_like 'does not add a phone error'
          end

          context 'and has dashes and prefix without plus sign' do
            let(:phone) { '1202-555-0123' }

            it_behaves_like 'does not add a phone error'
          end

          context 'and has dashes and prefix after dash' do
            let(:phone) { '1-202-555-0123' }

            it_behaves_like 'does not add a phone error'
          end

          context 'and has dashed and parenthesized' do
            let(:phone) { '(202) 555-0123' }

            it_behaves_like 'does not add a phone error'
          end

          context 'and has dashed and parenthesized and prefix' do
            let(:phone) { '+1(202) 555-0123' }

            it_behaves_like 'does not add a phone error'
          end

          context 'and has dashed and parenthesized and prefix without plus sign' do
            let(:phone) { '1(202) 555-0123' }

            it_behaves_like 'does not add a phone error'
          end
        end

        context 'and phone is invalid' do
          let(:address) { build_stubbed(:address, phone: phone) }

          context 'and phone is from another country' do
            let(:phone) { '+48587530227' } # Poland

            it 'adds an error' do
              subject.validate(address)
              expect(address.errors[:phone]).to include('is invalid')
            end
          end

          context 'because not matching US area code' do
            let(:phone) { '1234567890' }

            it 'adds an error' do
              subject.validate(address)
              expect(address.errors[:phone]).to include('is invalid')
            end
          end
        end
      end

      context 'because country is not matching phone' do
        let(:phone) { '+1(202) 555-0123' } # US
        let(:country) { create(:country, iso: 'PL') }
        let(:address) { build_stubbed(:address, phone: phone, country: country) }

        it 'adds an error' do
          subject.validate(address)
          expect(address.errors[:phone]).to include('is invalid')
        end
      end
    end
  end
end
