require 'spec_helper'
require 'rake'

describe 'spree:role_users:backfill_store_ids' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:role_users:backfill_store_ids' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'role_users.rake')
  end

  before { subject.reenable }

  let!(:store) { Spree::Store.default || create(:store, default: true) }
  let(:role) { create(:role, name: 'test_role') }
  let(:user) { create(:user) }

  # The ensure_store callback stamps store_id on create, so null it to reproduce a
  # row created before the column existed.
  def downgrade!(role_user)
    role_user.update_columns(store_id: nil)
    role_user
  end

  context 'store-scoped role assignment' do
    let!(:role_user) { downgrade!(Spree::RoleUser.create!(role: role, user: user, resource: store)) }

    it 'backfills store_id from the store resource' do
      expect { subject.invoke }.to change { role_user.reload.store_id }.from(nil).to(store.id)
    end

    it 'is idempotent — a re-run changes nothing' do
      subject.invoke
      subject.reenable
      expect { subject.invoke }.not_to change { role_user.reload.store_id }
    end
  end
end
