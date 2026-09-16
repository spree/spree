require 'spec_helper'

RSpec.describe Spree::ActedBy do
  # Spree::Order is the reference consumer — three actor associations on the
  # table the plan converts first.
  let(:store) { @default_store }
  let(:admin_user) { create(:admin_user) }
  let(:api_key) { create(:api_key, :secret, store: store) }

  describe 'the declared associations' do
    it 'lists what the model records' do
      expect(Spree::Order.acted_by_associations).to include(:created_by, :approver, :canceler)
      expect(Spree::Refund.acted_by_associations).to eq([:refunder])
      expect(Spree::StockReceipt.acted_by_associations).to eq([:received_by])
    end

    it 'is polymorphic and optional' do
      association = Spree::Order.reflect_on_association(:canceler)

      expect(association).to be_polymorphic
      expect(association.options[:optional]).to be(true)
    end

    it 'does not leak one model\'s names into another' do
      expect(Spree::Refund.acted_by_associations).not_to include(:canceler)
    end
  end

  describe 'accepting each registered actor kind' do
    it 'records an admin user' do
      order = create(:order, store: store, canceler: admin_user)

      expect(order.reload.canceler).to eq(admin_user)
      expect(order.canceler_type).to eq(Spree.admin_user_class.to_s)
    end

    it 'records an API key — the point of the conversion' do
      order = create(:order, store: store, canceler: api_key)

      expect(order.reload.canceler).to eq(api_key)
      expect(order.canceler_type).to eq('Spree::ApiKey')
    end
  end

  describe 'the type validation' do
    it 'refuses a class nobody registered' do
      order = build(:order, store: store, canceler_type: 'Spree::Product', canceler_id: 1)

      expect(order).not_to be_valid
      expect(order.errors[:canceler_type]).to include('is not a registered actor class')
    end

    it 'accepts a class an extension registers' do
      order = build(:order, store: store, canceler_type: 'Spree::Product', canceler_id: 1)

      expect { Spree.actor_classes << 'Spree::Product' }.
        to change { order.valid? }.from(false).to(true)
    ensure
      Spree.actor_classes.delete('Spree::Product')
    end

    it 'says nothing about a row with no actor' do
      expect(build(:order, store: store)).to be_valid
    end
  end

  describe 'the transitional reader' do
    # What an un-backfilled row looks like: an id written before the type
    # column existed.
    let(:order) do
      create(:order, store: store).tap do |record|
        record.update_columns(canceler_id: admin_user.id, canceler_type: nil)
      end
    end

    it 'resolves through the admin user class' do
      expect(order.reload.canceler).to eq(admin_user)
    end

    it 'warns so the backfill gets run' do
      expect(Spree::Deprecation).to receive(:warn).with(/backfill_actor_types/)

      order.reload.canceler
    end

    it 'steps aside once the type is present' do
      order.update_columns(canceler_type: Spree.admin_user_class.to_s)

      expect(Spree::Deprecation).not_to receive(:warn)
      expect(order.reload.canceler).to eq(admin_user)
    end

    # An un-backfilled page must not cost a query per actor: the fallback
    # names the type across the whole preloaded group, so the association
    # still batches.
    it 'batches an un-backfilled page the same as a backfilled one' do
      admin_queries = lambda do |&block|
        count = 0
        subscription = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          count += 1 if payload[:sql].to_s.include?('spree_admin_users') && !payload[:name].to_s.include?('SCHEMA')
        end
        block.call
        ActiveSupport::Notifications.unsubscribe(subscription)
        count
      end

      3.times { create(:order, store: store, canceler: admin_user) }
      read_page = -> { Spree::Order.preload_associations_lazily.last(3).each(&:canceler) }

      typed = admin_queries.call(&read_page)
      Spree::Order.update_all(canceler_type: nil)
      untyped = admin_queries.call(&read_page)

      expect(untyped).to eq(typed)
    end

    it 'names the type in memory only, never saving it' do
      order.reload.canceler

      expect(Spree::Order.where(id: order.id).pick(:canceler_type)).to be_nil
    end

    it 'answers nil for a row with no actor at all, without warning' do
      plain_order = create(:order, store: store)

      expect(Spree::Deprecation).not_to receive(:warn)
      expect(plain_order.canceler).to be_nil
    end
  end

  describe '.columns_for' do
    it 'produces both halves of the pair' do
      expect(described_class.columns_for(:canceler, admin_user)).
        to eq(canceler_id: admin_user.id, canceler_type: Spree.admin_user_class.to_s)
    end

    it 'clears both halves for no actor' do
      expect(described_class.columns_for(:canceler, nil)).to eq(canceler_id: nil, canceler_type: nil)
    end

    # These writes go through update_columns, which skips validation — so the
    # registry is enforced here or nowhere.
    it 'refuses an unregistered actor' do
      expect { described_class.columns_for(:canceler, create(:user)) }.
        to raise_error(ArgumentError, /not a registered actor class/)
    end
  end

  describe '.models' do
    it 'names every model that declares an actor' do
      expect(described_class.models).to include(Spree::Order, Spree::Refund, Spree::Return,
                                                Spree::Exchange, Spree::Claim, Spree::StockReceipt)
    end

    # The registry holds names and resolves them on read, so a code reload in
    # development cannot leave it pointing at superseded copies of a model.
    it 'answers live classes' do
      expect(described_class.models).to all(satisfy { |model| model.equal?(model.name.constantize) })
    end
  end
end
