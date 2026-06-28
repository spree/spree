require 'spec_helper'
require 'rake'

describe 'spree:upgrade:populate_single_store_associations' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:populate_single_store_associations' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'single_store_associations.rake')
  end

  before { subject.reenable }

  let!(:default_store) { Spree::Store.default || create(:store, default: true) }

  describe 'promotions' do
    let!(:promotion) { create(:promotion, store: default_store) }

    # Simulate the pre-5.6 state: store_id nil + a legacy join row.
    before do
      promotion.update_columns(store_id: nil)
      Spree::StorePromotion.create!(promotion: promotion, store: default_store)
    end

    it 'sets store_id from the legacy join row' do
      expect { subject.invoke }.to change { promotion.reload.store_id }.from(nil).to(default_store.id)
    end

    it 'is idempotent — a re-run changes nothing' do
      subject.invoke
      subject.reenable
      expect { subject.invoke }.not_to change { promotion.reload.store_id }
    end

    context 'when shared across multiple stores' do
      let!(:other_store) { create(:store, default: false) }

      before do
        # Earliest legacy row wins. Backdate the default-store row so it's
        # older than the other-store row and assert it's chosen.
        Spree::StorePromotion.where(promotion_id: promotion.id).update_all(created_at: 2.days.ago)
        Spree::StorePromotion.create!(promotion: promotion, store: other_store, created_at: 1.day.ago)
      end

      it 'assigns the earliest store and reports the shared record' do
        expect { subject.invoke }
          .to output(/shared across stores/).to_stdout
          .and change { promotion.reload.store_id }.from(nil).to(default_store.id)
      end
    end
  end

  describe 'payment methods' do
    let!(:payment_method) { create(:check_payment_method, store: default_store) }

    before do
      payment_method.update_columns(store_id: nil)
      Spree::StorePaymentMethod.create!(payment_method: payment_method, store: default_store)
    end

    it 'sets store_id from the legacy join row' do
      expect { subject.invoke }.to change { payment_method.reload.store_id }.from(nil).to(default_store.id)
    end

    context 'when shared across multiple stores' do
      let!(:other_store) { create(:store, default: false) }

      before do
        Spree::StorePaymentMethod.create!(payment_method: payment_method, store: other_store)
      end

      # No timestamps on the join — the lowest store_id is the deterministic owner.
      it 'assigns the lowest store_id' do
        subject.invoke
        expect(payment_method.reload.store_id).to eq([default_store.id, other_store.id].min)
      end
    end
  end

  context 'legacy tables not present' do
    before do
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).and_call_original
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).with('spree_promotions_stores').and_return(false)
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).with('spree_payment_methods_stores').and_return(false)
    end

    it 'no-ops with a message' do
      expect { subject.invoke }.to output(/not found/).to_stdout
    end
  end
end
