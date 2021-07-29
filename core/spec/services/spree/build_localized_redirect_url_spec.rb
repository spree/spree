require 'spec_helper'

module Spree
  describe BuildLocalizedRedirectUrl do
    subject { described_class.call(url: url, locale: locale, default_locale: default_locale) }

    let(:result) { subject.value }
    let(:default_locale) { 'en' }

    context 'root path' do
      context 'default locale' do
        let(:locale) { 'en' }

        context 'http with port' do
          let(:url) { 'http://example.com:3000/' }

          it { expect(result).to eq('http://example.com:3000') }
        end

        context 'https with no trailing slash' do
          let(:url) { 'https://example.com' }

          it { expect(result).to eq('https://example.com') }
        end

        context 'with parameters and port' do
          let(:url) { 'https://example.com:3000/?utm_source=google' }

          it { expect(result).to eq('https://example.com:3000?utm_source=google') }
        end
      end

      context 'non-default locale' do
        let(:locale) { 'de' }

        context 'http with port' do
          let(:url) { 'http://example.com:3000/' }

          it { expect(result).to eq('http://example.com:3000/de') }
        end

        context 'https with no trailing slash' do
          let(:url) { 'https://example.com' }

          it { expect(result).to eq('https://example.com/de') }
        end

        context 'with parameters and port' do
          let(:url) { 'https://example.com:3000/?utm_source=google' }

          it { expect(result).to eq('https://example.com:3000/de?utm_source=google') }
        end

        context 'with long locale symbols' do
          let(:locale) { 'es-MX' }

          context 'http with port' do
            let(:url) { 'http://example.com:3000/' }

            it { expect(result).to eq('http://example.com:3000/es-MX') }
          end

          context 'https with no trailing slash' do
            let(:url) { 'https://example.com' }

            it { expect(result).to eq('https://example.com/es-MX') }
          end

          context 'with parameters and port' do
            let(:url) { 'https://example.com:3000/?utm_source=google' }

            it { expect(result).to eq('https://example.com:3000/es-MX?utm_source=google') }
          end
        end
      end
    end

    context 'localized path' do
      context 'default locale' do
        let(:locale) { 'en' }

        context 'http with port' do
          let(:url) { 'http://example.com:3000/fr/products/some-product' }

          it { expect(result).to eq('http://example.com:3000/products/some-product') }
        end

        context 'https with no trailing slash' do
          let(:url) { 'https://example.com/fr/products/some-product' }

          it { expect(result).to eq('https://example.com/products/some-product') }
        end

        context 'with parameters and port' do
          let(:url) { 'https://example.com:3000/fr/products/some-product?taxon_id=1&utm_source=google' }

          it { expect(result).to eq('https://example.com:3000/products/some-product?taxon_id=1&utm_source=google') }
        end

        context 'with long locale symbols' do
          context 'http with port' do
            let(:url) { 'http://example.com:3000/es-MX/products/some-product' }

            it { expect(result).to eq('http://example.com:3000/products/some-product') }
          end

          context 'https with no trailing slash' do
            let(:url) { 'https://example.com/es-MX/products/some-product' }

            it { expect(result).to eq('https://example.com/products/some-product') }
          end

          context 'with parameters and port' do
            let(:url) { 'https://example.com:3000/es-MX/products/some-product?taxon_id=1&utm_source=google' }

            it { expect(result).to eq('https://example.com:3000/products/some-product?taxon_id=1&utm_source=google') }
          end
        end
      end

      context 'non-default locale' do
        let(:locale) { 'de' }

        context 'http with port' do
          let(:url) { 'http://example.com:3000/fr/products/some-product' }

          it { expect(result).to eq('http://example.com:3000/de/products/some-product') }
        end

        context 'https with no trailing slash' do
          let(:url) { 'https://example.com/fr/products/some-product' }

          it { expect(result).to eq('https://example.com/de/products/some-product') }
        end

        context 'with parameters and port' do
          let(:url) { 'https://example.com:3000/fr/products/some-product?taxon_id=1&utm_source=google' }

          it { expect(result).to eq('https://example.com:3000/de/products/some-product?taxon_id=1&utm_source=google') }
        end

        context 'with long locale symbols' do
          context 'http with port' do
            let(:url) { 'http://example.com:3000/es-MX/products/some-product' }

            it { expect(result).to eq('http://example.com:3000/de/products/some-product') }
          end

          context 'https with no trailing slash' do
            let(:url) { 'https://example.com/es-MX/products/some-product' }

            it { expect(result).to eq('https://example.com/de/products/some-product') }
          end

          context 'with parameters and port' do
            let(:url) { 'https://example.com:3000/es-MX/products/some-product?taxon_id=1&utm_source=google' }

            it { expect(result).to eq('https://example.com:3000/de/products/some-product?taxon_id=1&utm_source=google') }
          end
        end
      end

      context 'es-MX' do
        let(:locale) { 'es-MX' }

        context 'http with port' do
          let(:url) { 'http://example.com:3000/fr/products/some-product' }

          it { expect(result).to eq('http://example.com:3000/es-MX/products/some-product') }
        end

        context 'https with no trailing slash' do
          let(:url) { 'https://example.com/fr/products/some-product' }

          it { expect(result).to eq('https://example.com/es-MX/products/some-product') }
        end

        context 'with parameters and port' do
          let(:url) { 'https://example.com:3000/fr/products/some-product?taxon_id=1&utm_source=google' }

          it { expect(result).to eq('https://example.com:3000/es-MX/products/some-product?taxon_id=1&utm_source=google') }
        end
      end
    end

    context 'not supported path' do
      context 'default store locale' do
        let(:locale) { 'en' }

        context 'http with port' do
          let(:url) { 'http://example.com:3000/account?locale=fr' }

          it { expect(result).to eq('http://example.com:3000/account') }
        end

        context 'https with no trailing slash' do
          let(:url) { 'https://example.com/login/?locale=fr' }

          it { expect(result).to eq('https://example.com/login') }
        end

        context 'with parameters and port' do
          let(:url) { 'https://example.com:3000/login?locale=fr&utm_source=google' }

          it { expect(result).to eq('https://example.com:3000/login?utm_source=google') }
        end
      end

      context 'non-default locale' do
        let(:locale) { 'de' }

        context 'http with port' do
          let(:url) { 'http://example.com:3000/login/' }

          it { expect(result).to eq('http://example.com:3000/login?locale=de') }
        end

        context 'https with no trailing slash' do
          let(:url) { 'https://example.com/account' }

          it { expect(result).to eq('https://example.com/account?locale=de') }
        end

        context 'with parameters and port' do
          let(:url) { 'https://example.com:3000/login?locale=fr&utm_source=google' }

          it { expect(result).to eq('https://example.com:3000/login?locale=de&utm_source=google') }
        end
      end
    end

    context 'default_locale is nil' do
      let(:default_locale) { nil }
      let(:locale) { 'de' }
      let(:url) { 'http://example.com:3000/products' }

      it { expect { subject }.not_to raise_error }
      it { expect { result }.not_to raise_error }
    end

    context 'subdomain as host' do
      let(:locale) { 'de' }
      let(:url) { 'http://subdomain.example.com:3000/products' }

      it { expect(result).to eq('http://subdomain.example.com:3000/de/products') }
    end
  end
end
