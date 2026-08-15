require 'spec_helper'

RSpec.describe Spree::Seeds::AdminUser do
  subject { described_class.call }

  context 'with ADMIN_EMAIL and ADMIN_PASSWORD set' do
    before do
      stub_const('ENV', ENV.to_h.merge('ADMIN_EMAIL' => 'boss@example.com', 'ADMIN_PASSWORD' => 'Secret123!'))
    end

    it 'creates the admin and binds it to the default store' do
      expect { subject }.to change(Spree.admin_user_class, :count).by(1)

      admin = Spree.admin_user_class.find_by(email: 'boss@example.com')
      expect(admin.spree_roles.for_resource(@default_store)).to exist
    end

    it 'does nothing when an admin already exists' do
      create(:admin_user)

      expect { subject }.not_to change(Spree.admin_user_class, :count)
    end

    # This install never sees the setup screen, so the seed answers the
    # country question itself — defaulting to what it hardcoded before.
    it 'provisions the country-shaped defaults as US by default' do
      subject

      store = @default_store.reload
      expect(store.default_country_code).to eq('US')
      expect(store.stock_locations.find_by(default: true).country_code).to eq('US')
      expect(store.delivery_zones.find_by(name: 'Domestic').members.pluck(:country_code)).to eq(['US'])
    end

    context 'with STORE_COUNTRY and STORE_LOCALE set' do
      before do
        stub_const(
          'ENV',
          ENV.to_h.merge(
            'ADMIN_EMAIL' => 'boss@example.com',
            'ADMIN_PASSWORD' => 'Secret123!',
            'STORE_COUNTRY' => 'DE',
            'STORE_LOCALE' => 'de'
          )
        )
      end

      it 'provisions the store for that country' do
        subject

        store = @default_store.reload
        expect(store.default_country_code).to eq('DE')
        expect(store.default_currency).to eq('EUR')
        expect(store.default_locale).to eq('de')
        expect(store.delivery_zones.find_by(name: 'Domestic').members.pluck(:country_code)).to eq(['DE'])
      end
    end

    context 'with an unknown STORE_COUNTRY' do
      before do
        stub_const(
          'ENV',
          ENV.to_h.merge(
            'ADMIN_EMAIL' => 'boss@example.com',
            'ADMIN_PASSWORD' => 'Secret123!',
            'STORE_COUNTRY' => 'ZZ'
          )
        )
      end

      it 'falls back to the US rather than failing the seed' do
        expect { subject }.not_to raise_error

        expect(@default_store.reload.default_country_code).to eq('US')
      end
    end
  end

  context 'without explicit credentials' do
    before do
      stub_const('ENV', ENV.to_h.except('ADMIN_EMAIL', 'ADMIN_PASSWORD'))
    end

    it 'creates no admin and leaves the setup token announceable' do
      expect { subject }.not_to change(Spree.admin_user_class, :count)
      expect(@default_store.reload.setup_token).to be_present
    end

    it 'does not rotate the token on a repeated run' do
      described_class.call
      token = @default_store.reload.setup_token

      described_class.call

      expect(@default_store.reload.setup_token).to eq(token)
    end

    it 'regenerates a missing token (stores predating the column)' do
      @default_store.update_column(:setup_token, nil)

      subject

      expect(@default_store.reload.setup_token).to be_present
    end
  end
end
