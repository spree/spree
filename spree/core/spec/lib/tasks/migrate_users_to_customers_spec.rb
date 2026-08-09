require 'spec_helper'
require 'rake'

describe 'spree:upgrade:migrate_users_to_customers' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:migrate_users_to_customers' }

  # A dedicated, non-shared source table. The dummy already ships a (bare, empty)
  # spree_users from the legacy 4.3 schema, so we must NOT create/drop that shared
  # table — instead build a realistically-shaped legacy customer table and point
  # the task at it via SOURCE_USER_TABLE. DDL lives in before/after(:all) so it
  # sits outside the per-example transaction.
  let(:source_table) { 'spree_legacy_source_users' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'migrate_users_to_customers.rake')

    ActiveRecord::Base.connection.create_table :spree_legacy_source_users, force: true do |t|
      t.string :email
      t.string :encrypted_password
      t.string :first_name
      t.string :last_name
      t.string :phone
      t.string :selected_locale
      t.boolean :accepts_email_marketing
      t.bigint :bill_address_id
      t.bigint :ship_address_id
      t.integer :failed_attempts
      t.datetime :locked_at
      t.timestamps
    end
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table :spree_legacy_source_users, if_exists: true
  end

  before do
    subject.reenable
    ENV['SOURCE_USER_TABLE'] = source_table
    # Devise is gone in 6.0, so the task can't introspect a former pepper — the
    # examples assert the confirmed no-pepper happy path.
    ENV['CONFIRM_NO_PEPPER'] = 'true'
  end

  after do
    ENV.delete('SOURCE_USER_TABLE')
    ENV.delete('CONFIRM_NO_PEPPER')
  end

  # Raw handle on the legacy table — no validations, lets us set explicit ids.
  let(:legacy_users) { Class.new(Spree.base_class) { self.table_name = 'spree_legacy_source_users' } }

  describe 'copying customers' do
    # High, out-of-range ids so copied rows never collide with factory-created
    # customers (which start their own low id sequence).
    before do
      legacy_users.create!(id: 900_001, email: 'alice@example.com', encrypted_password: 'alice_digest',
                           first_name: 'Alice', accepts_email_marketing: true, failed_attempts: 2)
      legacy_users.create!(id: 900_002, email: 'bob@example.com', encrypted_password: 'bob_digest')
    end

    it 'copies rows preserving id and mapping encrypted_password to password_digest' do
      subject.invoke

      alice = Spree.customer_class.find(900_001)
      expect(alice.email).to eq('alice@example.com')
      expect(alice.first_name).to eq('Alice')
      expect(alice.accepts_email_marketing).to be(true)
      expect(alice.failed_attempts).to eq(2)
      expect(alice.password_digest).to eq('alice_digest')

      expect(Spree.customer_class.exists?(900_002)).to be(true)
      # accepts_email_marketing is NOT NULL — a legacy nil must land as false.
      expect(Spree.customer_class.find(900_002).accepts_email_marketing).to be(false)
    end

    describe 'invalid source rows' do
      it 'aborts and copies nothing when a source row has a blank email' do
        legacy_users.create!(id: 900_010, email: '', encrypted_password: 'ghost_digest')

        expect { subject.invoke }.to raise_error(SystemExit)
        expect(Spree.customer_class.exists?(900_001)).to be(false)
      end

      it 'aborts when a source email is already owned by a different customer' do
        create(:user, email: 'alice@example.com')

        expect { subject.invoke }.to raise_error(SystemExit)
      end

      it 'treats email conflicts case-insensitively' do
        legacy_users.create!(id: 900_011, email: 'Carol@Example.com', encrypted_password: 'x')
        create(:user, email: 'carol@example.com')

        expect { subject.invoke }.to raise_error(SystemExit)
      end

      it 'skips invalid rows and copies the rest with SKIP_INVALID_ROWS=true' do
        legacy_users.create!(id: 900_010, email: '', encrypted_password: 'ghost_digest')
        ENV['SKIP_INVALID_ROWS'] = 'true'

        subject.invoke

        expect(Spree.customer_class.exists?(900_010)).to be(false)
        expect(Spree.customer_class.exists?(900_001)).to be(true)
      ensure
        ENV.delete('SKIP_INVALID_ROWS')
      end
    end

    it 'advances the primary key sequence past the copied ids' do
      subject.invoke

      new_customer = Spree.customer_class.create!(email: 'new@example.com', password: 'secret123')
      expect(new_customer.id.to_i).to be > 900_002
    end

    it 'is idempotent — a re-run copies nothing new and does not error' do
      subject.invoke
      subject.reenable

      expect { subject.invoke }.not_to change { Spree.customer_class.count }
    end
  end

  describe 're-pointing polymorphic user_type' do
    let!(:token) { create(:refresh_token).tap { |r| r.update_columns(user_type: 'Spree::User') } }
    let!(:identity) { create(:user_identity).tap { |i| i.update_columns(user_type: 'Spree::User') } }
    let!(:role_user) { create(:role_user).tap { |ru| ru.update_columns(user_type: 'Spree::User') } }
    let!(:api_key) { create(:api_key, :secret).tap { |k| k.update_columns(created_by_type: 'Spree::User', created_by_id: 1) } }
    # Customer-group membership stores the type in the renamed customer_type column.
    let!(:group_membership) { create(:customer_group_user).tap { |m| m.update_columns(customer_type: 'Spree::User') } }

    it 'flips Spree::User references to Spree::Customer' do
      subject.invoke

      expect(token.reload.user_type).to eq('Spree::Customer')
      expect(identity.reload.user_type).to eq('Spree::Customer')
      expect(role_user.reload.user_type).to eq('Spree::Customer')
      expect(api_key.reload.created_by_type).to eq('Spree::Customer')
      expect(group_membership.reload.customer_type).to eq('Spree::Customer')
    end

    # Internal notes, so spree:migrate_rich_text_to_columns finds them under the
    # new class name. Inserted directly — Spree::User is gone in 6.0, so Action
    # Text cannot resolve the polymorphic owner.
    it 'flips internal-note Action Text rows to Spree::Customer' do
      ActionText::RichText.insert!(
        {
          name: 'internal_note', body: '<p>VIP</p>', locale: 'en',
          record_type: 'Spree::User', record_id: 1,
          created_at: Time.current, updated_at: Time.current
        }
      )

      subject.invoke

      expect(ActionText::RichText.where(name: 'internal_note').pick(:record_type)).to eq('Spree::Customer')
    end

    it 'leaves admin references untouched' do
      admin_token = create(:refresh_token, :for_admin)

      subject.invoke

      expect(admin_token.reload.user_type).to eq('Spree::AdminUser')
    end
  end

  describe 'backfilling admin password_digest' do
    let!(:admin) { create(:admin_user) }

    before { admin.update_columns(encrypted_password: 'legacy_admin_digest', password_digest: nil) }

    it 'copies encrypted_password into a blank password_digest in place' do
      subject.invoke

      expect(admin.reload.password_digest).to eq('legacy_admin_digest')
    end
  end

  describe 'guards' do
    it 'aborts when a Devise pepper is configured' do
      stub_const('Devise', Class.new { def self.pepper; 'peppered'; end })

      expect { subject.invoke }.to raise_error(SystemExit)
    end

    it 'aborts when Devise is absent and no-pepper is unconfirmed' do
      ENV.delete('CONFIRM_NO_PEPPER')

      expect { subject.invoke }.to raise_error(SystemExit)
    end

    it 'no-ops when the source table is absent' do
      ENV['SOURCE_USER_TABLE'] = 'a_table_that_does_not_exist'

      expect { subject.invoke }.to output(/nothing to migrate/).to_stdout
    end
  end
end
