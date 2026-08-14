require 'spec_helper'

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
  # before 6.0; every code that seed could produce must still resolve, or
  # upgrading silently invalidates addresses that were valid when entered.
  #
  # The list is frozen rather than regenerated from Carmen: the gem is gone in
  # 6.0, and what matters is the data real stores were seeded with, which no
  # longer changes.
  describe 'compatibility with the pre-6.0 seeded data' do
    SEEDED_STATE_CODES = {
      "AU" => %w[ACT NSW NT QLD SA TAS VIC WA],
      "AE" => %w[AJ AZ DU FU RK SH UQ],
      "BR" => %w[AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO],
      "CA" => %w[AB BC MB NB NL NS NT NU ON PE QC SK YT],
      "CN" => %w[AH BJ CQ FJ GD GS GX GZ HA HB HE HI HL HN JL JS JX LN NM NX QH SC SD SH SN SX TJ XJ XZ YN ZJ],
      "ES" => %w[A AB AL AV B BA BI BU C CA CC CE CO CR CS CU GC GI GR GU H HU J L LE LO LU M MA ML MU NA O OR P PM PO S SA SE SG SO SS T TE TF TO V VA VI Z ZA],
      "IE" => %w[CE CN CO CW D DL G KE KK KY LD LH LK LM LS MH MN MO OY RN SO TA WD WH WW WX],
      "IN" => %w[AN AP AR AS BR CH CT DD DL DN GA GJ HP HR JH JK KA KL LD MH ML MN MP MZ NL OR PB PY RJ SK TG TN TR UP UT WB],
      "IT" => %w[AG AL AN AO AP AQ AR AT AV BA BG BI BL BN BO BR BS BT BZ CA CB CE CH CI CL CN CO CR CS CT CZ EN FC FE FG FI FM FR GE GO GR IM IS KR LC LE LI LO LT LU MB MC ME MI MN MO MS MT NA NO NU OG OR OT PA PC PD PE PG PI PN PO PR PT PU PV PZ RA RC RE RG RI RM RN RO SA SI SO SP SR SS SV TA TE TN TO TP TR TS TV UD VA VB VC VE VI VR VS VT VV],
      "MY" => %w[01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16],
      "MX" => %w[AGU BCN BCS CAM CHH CHP CMX COA COL DUR GRO GUA HID JAL MEX MIC MOR NAY NLE OAX PUE QUE ROO SIN SLP SON TAB TAM TLA VER YUC ZAC],
      "NZ" => %w[AUK BOP CAN CIT GIS HKB MBH MWT NSN NTL OTA STL TAS TKI WGN WKO WTC],
      "PT" => %w[01 02 03 04 05 06 07 08 09 10 11 12 13 14 15 16 17 18 20 30],
      "RO" => %w[AB AG AR B BC BH BN BR BT BV BZ CJ CL CS CT CV DB DJ GJ GL GR HD HR IF IL IS MH MM MS NT OT PH SB SJ SM SV TL TM TR VL VN VS],
      "TH" => %w[10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 30 31 32 33 34 35 36 37 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 60 61 62 63 64 65 66 67 70 71 72 73 74 75 76 77 80 81 82 83 84 85 86 90 91 92 93 94 95 96 S],
      "US" => %w[AA AE AK AL AP AR AZ CA CO CT DC DE FL GA HI IA ID IL IN KS KY LA MA MD ME MI MN MO MS MT NC ND NE NH NJ NM NV NY OH OK OR PA RI SC SD TN TX UT VA VT WA WI WV WY],
      "ZA" => %w[EC FS GT LP MP NC NL NW WC],
    }.freeze

    SEEDED_STATE_CODES.each do |iso, codes|
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
