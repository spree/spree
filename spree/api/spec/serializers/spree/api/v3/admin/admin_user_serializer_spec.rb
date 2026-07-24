# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::AdminUserSerializer do
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }

  subject { described_class.new(admin_user, params: { store: store }).to_h }

  describe 'stores' do
    it 'lists every store the user holds a role on, not just the current one' do
      other_store = create(:store)
      create(:role_user, user: admin_user, role: Spree::Role.default_admin_role, resource: other_store, store: other_store)

      expect(subject['stores']).to contain_exactly(
        { id: store.prefixed_id, name: store.name, code: store.code },
        { id: other_store.prefixed_id, name: other_store.name, code: other_store.code }
      )
    end

    it 'does not duplicate a store the user holds multiple roles on' do
      create(:role_user, user: admin_user, role: create(:role), resource: store, store: store)

      expect(subject['stores'].map { |s| s[:id] }).to eq([store.prefixed_id])
    end
  end
end
