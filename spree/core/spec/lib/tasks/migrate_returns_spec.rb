require 'spec_helper'

# The migrator lives in the rake file (it is a one-release upgrade step, not
# engine infrastructure), so load it the way the task does.
load Spree::Core::Engine.root.join('lib', 'tasks', 'migrate_returns.rake') unless defined?(Spree::ReturnsMigrator)

RSpec.describe Spree::ReturnsMigrator do
  let(:order) { create(:shipped_order, store: @default_store) }
  let(:fulfillment_item) { order.fulfillment_items.first }
  let(:stock_location) { order.fulfillments.first.stock_location }

  subject(:migrate) { described_class.new.call }

  # The legacy models are gone, so seed the old tables the same way the
  # migrator reads them — by name.
  def insert_authorization(state: 'authorized', number: 'RA100')
    ActiveRecord::Base.connection.insert(<<~SQL.squish)
      INSERT INTO spree_return_authorizations
        (number, state, order_id, memo, stock_location_id, created_at, updated_at)
      VALUES
        ('#{number}', '#{state}', #{order.id}, 'Legacy memo', #{stock_location.id},
         '#{1.day.ago.to_fs(:db)}', '#{1.day.ago.to_fs(:db)}')
    SQL
  end

  # SQLite takes 1/0 for booleans, PostgreSQL does not — ask the adapter.
  def quoted_true
    ActiveRecord::Base.connection.quoted_true
  end

  def insert_item(authorization_id, exchange_variant_id: nil, reception_status: 'awaiting',
                  reimbursement_id: nil, pre_tax_amount: 10.0)
    ActiveRecord::Base.connection.insert(<<~SQL.squish)
      INSERT INTO spree_return_items
        (return_authorization_id, fulfillment_item_id, exchange_variant_id, reception_status,
         reimbursement_id, pre_tax_amount, resellable, created_at, updated_at)
      VALUES
        (#{authorization_id}, #{fulfillment_item.id},
         #{exchange_variant_id || 'NULL'}, '#{reception_status}',
         #{reimbursement_id || 'NULL'}, #{pre_tax_amount}, #{quoted_true},
         '#{1.day.ago.to_fs(:db)}', '#{1.day.ago.to_fs(:db)}')
    SQL
  end

  context 'with a plain return authorization' do
    before do
      id = insert_authorization
      insert_item(id, reception_status: 'received')
    end

    it 'creates a return carrying the legacy number and memo' do
      expect { migrate }.to change(Spree::Return, :count).by(1)

      return_record = Spree::Return.last
      expect(return_record.number).to eq('RA100')
      expect(return_record.memo).to eq('Legacy memo')
      expect(return_record.order).to eq(order)
      expect(return_record.stock_location).to eq(stock_location)
      expect(return_record.status).to eq('received')
    end

    it 'reports what it did' do
      expect(migrate).to include(returns: 1, exchanges: 0, skipped: 0)
    end

    it 'copies the line with its received quantity and amount' do
      migrate

      line = Spree::Return.last.return_line_items.first
      expect(line.fulfillment_item).to eq(fulfillment_item)
      expect(line.variant).to eq(fulfillment_item.variant)
      expect(line.pre_tax_amount).to eq(10.0)
      expect(line.received_quantity).to eq(1)
    end
  end

  context 'when a return item names an exchange variant' do
    let(:replacement) { create(:variant) }

    before do
      id = insert_authorization(number: 'RA200')
      insert_item(id, exchange_variant_id: replacement.id, reception_status: 'received')
    end

    it 'creates an exchange rather than a return' do
      expect { migrate }.to change(Spree::Exchange, :count).by(1).and change(Spree::Return, :count).by(0)

      exchange = Spree::Exchange.last
      expect(exchange.number).to eq('RA200')

      line = exchange.exchange_line_items.first
      expect(line.original_variant).to eq(fulfillment_item.variant)
      expect(line.new_variant).to eq(replacement)
    end
  end

  context 'when the authorization was canceled' do
    before do
      id = insert_authorization(state: 'canceled', number: 'RA300')
      insert_item(id)
    end

    it 'carries the canceled status across' do
      migrate
      expect(Spree::Return.last.status).to eq('canceled')
    end
  end

  # The scoping that replaces a cursor: already-migrated numbers are excluded
  # by the query, so a re-run is a no-op and an interrupted run resumes.
  describe 'scoping to unmigrated rows' do
    before do
      id = insert_authorization(number: 'RA400')
      insert_item(id)
    end

    # A fresh instance per run — each invocation is a separate `rake` call.
    it 'does not duplicate rows on a second run' do
      migrate
      expect { described_class.new.call }.not_to change(Spree::Return, :count)
    end

    it 'migrates only what is left when a previous run was interrupted' do
      migrate
      later = insert_authorization(number: 'RA401')
      insert_item(later)

      expect { described_class.new.call }.to change(Spree::Return, :count).by(1)
      expect(Spree::Return.pluck(:number)).to match_array(%w[RA400 RA401])
    end
  end

  # NumberGenerator runs in a before_validation hook, which save!(validate: false)
  # skips — so a numberless legacy row would hit the NOT NULL constraint without
  # an explicit fallback.
  context 'when the legacy row has no number' do
    before do
      id = ActiveRecord::Base.connection.insert(<<~SQL.squish)
        INSERT INTO spree_return_authorizations
          (number, state, order_id, stock_location_id, created_at, updated_at)
        VALUES
          (NULL, 'authorized', #{order.id}, #{stock_location.id},
           '#{1.day.ago.to_fs(:db)}', '#{1.day.ago.to_fs(:db)}')
      SQL
      insert_item(id)
    end

    it 'migrates it with a generated number' do
      expect { migrate }.to change(Spree::Return, :count).by(1)
      expect(Spree::Return.last.number).to be_present
    end

    it 'does not report it as both migrated and failed' do
      result = migrate
      expect(result[:failed]).to be_empty
      expect(result[:returns]).to eq(1)
    end

    # `NULL NOT IN (...)` is UNKNOWN, so a numberless row is invisible to the
    # number-based exclusion in both directions: it would never migrate at
    # all, or — once forced through — migrate again on every run under a
    # fresh generated number.
    it 'migrates it exactly once across repeated runs' do
      migrate

      expect { described_class.new.call }.not_to change(Spree::Return, :count)
    end

    it 'records the legacy id so the row can be recognised again' do
      migrate

      # The column, not #metadata — that reader maps to private_metadata,
      # which spree_returns does not have.
      stamped = Spree::Return.last.read_attribute(:metadata)
      stamped = JSON.parse(stamped) unless stamped.is_a?(Hash)
      expect(stamped['legacy_return_authorization_id']).to be_present
    end
  end

  context 'when the authorization has no items' do
    before { insert_authorization(number: 'RA500') }

    it 'skips it rather than creating an invalid return' do
      expect { migrate }.not_to change(Spree::Return, :count)
      expect(described_class.new.call).to include(skipped: 1)
    end
  end

  context 'when there is nothing to migrate' do
    it 'reports zero counts' do
      expect(migrate).to include(returns: 0, exchanges: 0)
    end
  end
end
