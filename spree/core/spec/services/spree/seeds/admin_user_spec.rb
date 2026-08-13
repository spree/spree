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
      expect(admin.role_users.exists?(store: @default_store)).to be(true)
    end

    it 'does nothing when an admin already exists' do
      create(:admin_user)

      expect { subject }.not_to change(Spree.admin_user_class, :count)
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
