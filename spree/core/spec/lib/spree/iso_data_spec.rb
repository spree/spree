require 'spec_helper'
require 'carmen'

RSpec.describe Spree::IsoData do
  describe '.countries' do
    it 'omits territories that can never be ordered to' do
      expect(described_class.countries.map(&:alpha2)).not_to include('AQ', 'UM', 'BV')
    end

    it 'keeps the countries a store actually sells to' do
      expect(described_class.countries.map(&:alpha2)).to include('US', 'DE', 'PL', 'AR')
    end
  end

  describe '.country' do
    it 'looks up by alpha-2, alpha-3 and mixed case' do
      expect(described_class.country('US').alpha2).to eq('US')
      expect(described_class.country('USA').alpha2).to eq('US')
      expect(described_class.country('us').alpha2).to eq('US')
    end

    it 'returns nil for unknown and excluded codes' do
      expect(described_class.country('XX')).to be_nil
      expect(described_class.country('AQ')).to be_nil
      expect(described_class.country(nil)).to be_nil
    end
  end

  describe '.subdivisions' do
    it 'lists the fifty states, DC and the military codes for the US' do
      subdivisions = described_class.subdivisions('US')

      expect(subdivisions['CA']).to eq('California')
      expect(subdivisions['DC']).to eq('District of Columbia')
      expect(subdivisions).to include('AA', 'AE', 'AP')
    end

    it 'omits US outlying areas, which Spree treats as separate countries' do
      expect(described_class.subdivisions('US')).not_to include('PR', 'GU', 'VI')
    end

    it 'omits Hong Kong, Macao and Taiwan from China' do
      expect(described_class.subdivisions('CN')).not_to include('HK', 'MO', 'TW')
    end

    it 'is empty for a country with no subdivisions' do
      expect(described_class.subdivisions('HK')).to be_empty
    end

    # The gem keys subdivision translations by symbol, unlike country
    # translations, so a string lookup silently falls back to English.
    context 'when the locale has subdivision translations' do
      # The gem caches subdivision data, so a locale change only takes effect
      # once that cache is dropped. In an app this happens once at boot.
      around do |example|
        original = ISO3166.configuration.locales
        reload_iso3166_with_locales(%w[en de])
        I18n.with_locale(:de) { example.run }
        reload_iso3166_with_locales(original)
      end

      def reload_iso3166_with_locales(locales)
        ISO3166.configure { |config| config.locales = locales }
        ISO3166::Data.reset
        described_class.reset!
      end

      it 'translates subdivision names' do
        expect(described_class.subdivision_name('US', 'CA')).to eq('Kalifornien')
      end

      it 'leaves names Spree supplies itself untranslated' do
        expect(described_class.subdivision_name('US', 'AA')).to eq('Armed Forces Americas')
      end
    end
  end

  describe '.subdivision_code' do
    it 'accepts a current code in any case' do
      expect(described_class.subdivision_code('US', 'CA')).to eq('CA')
      expect(described_class.subdivision_code('US', 'ca')).to eq('CA')
    end

    it 'accepts a subdivision name' do
      expect(described_class.subdivision_code('US', 'California')).to eq('CA')
      expect(described_class.subdivision_code('US', 'california')).to eq('CA')
    end

    it 'returns nil when nothing matches' do
      expect(described_class.subdivision_code('US', 'Nonsense')).to be_nil
      expect(described_class.subdivision_code('US', nil)).to be_nil
    end

    # An address stored under a code ISO has since retired still has to resolve,
    # or upgrading would invalidate it.
    {
      %w[ZA GT] => 'GP',
      %w[ZA NL] => 'ZN',
      %w[IN CT] => 'CG',
      %w[IN OR] => 'OD',
      %w[IN TG] => 'TS',
      %w[IN UT] => 'UK',
      %w[IN DD] => 'DH',
      %w[IN DN] => 'DH',
      %w[IT AO] => '23'
    }.each do |(iso, retired), current|
      it "maps the retired #{iso} code #{retired} onto #{current}" do
        expect(described_class.subdivision_code(iso, retired)).to eq(current)
      end
    end
  end

  # The guard that keeps the curation honest. Spree seeded states from Carmen
  # before 6.0; every code that seed could produce must still resolve, otherwise
  # upgrading silently invalidates addresses that were valid when entered.
  describe 'compatibility with the pre-6.0 seeded data' do
    excluded_us_states = %w[UM AS MP VI PR GU].freeze
    excluded_cn_states = %w[HK MO TW].freeze

    # Mirrors the old Spree::Seeds::States branching exactly.
    def self.seeded_codes_for(iso, excluded_us, excluded_cn)
      carmen_country = Carmen::Country.coded(iso)
      return [] unless carmen_country

      carmen_country.subregions.flat_map do |subregion|
        case iso
        when 'US' then excluded_us.include?(subregion.code) ? [] : [subregion.code]
        when 'CA', 'MX' then [subregion.code]
        when 'CN' then excluded_cn.include?(subregion.code) ? [] : [subregion.code]
        else
          subregion.subregions? && subregion.subregions.size.positive? ? subregion.subregions.map(&:code) : [subregion.code]
        end
      end.reject { |code| code.nil? || code.empty? }.uniq
    end

    Spree::Address::STATES_REQUIRED.each do |iso|
      codes = seeded_codes_for(iso, excluded_us_states, excluded_cn_states)
      next if codes.empty?

      it "resolves every state code the seed produced for #{iso}" do
        unresolved = codes.reject { |code| described_class.subdivision_code(iso, code) }

        expect(unresolved).to be_empty,
                              "#{iso} codes no longer resolvable: #{unresolved.inspect}. " \
                              'Add them to SUBDIVISION_ADDITIONS or SUBDIVISION_ALIASES.'
      end
    end
  end

  describe 'the alias table' do
    it 'only points at subdivisions that exist' do
      dangling = described_class::SUBDIVISION_ALIASES.flat_map do |iso, mapping|
        available = described_class.subdivisions(iso)
        mapping.filter_map { |from, to| "#{iso}/#{from}->#{to}" unless available.key?(to) }
      end

      expect(dangling).to be_empty
    end
  end
end
