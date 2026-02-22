require 'spec_helper'

describe Spree::AdminUserMethods do
  let(:admin_user) { create(:admin_user) }
  let(:current_store) { @default_store }

  describe 'associations' do
    it { expect(admin_user).to have_many(:identities).dependent(:destroy) }
    it { expect(admin_user).to have_many(:canceled_orders) }
    it { expect(admin_user).to have_many(:created_orders) }
    it { expect(admin_user).to have_many(:approved_orders) }
    it { expect(admin_user).to have_many(:created_gift_cards) }
    it { expect(admin_user).to have_many(:created_gift_card_batches) }
    it { expect(admin_user).to have_many(:refunded_refunds) }
    it { expect(admin_user).to have_many(:performed_reimbursements) }
    it { expect(admin_user).to have_many(:authored_posts) }
    it { expect(admin_user).to have_many(:created_store_credits) }
    it { expect(admin_user).to have_many(:reports) }
    it { expect(admin_user).to have_many(:exports) }
  end

  describe 'prefixed_id' do
    it 'generates a prefixed_id starting with admin_' do
      expect(admin_user.prefixed_id).to start_with('admin_')
    end

    it 'uses prefixed_id as to_param' do
      expect(admin_user.to_param).to eq(admin_user.prefixed_id)
    end
  end

  describe 'normalizations' do
    it 'normalizes email' do
      admin_user.update(email: '  ADMIN@EXAMPLE.COM  ')
      expect(admin_user.email).to eq('ADMIN@EXAMPLE.COM')
    end

    it 'normalizes first_name' do
      admin_user.update(first_name: '  John  ')
      expect(admin_user.first_name).to eq('John')
    end

    it 'normalizes last_name' do
      admin_user.update(last_name: '  Doe  ')
      expect(admin_user.last_name).to eq('Doe')
    end
  end

  describe '#full_name' do
    context 'when names are present' do
      before do
        admin_user.update(first_name: 'John', last_name: 'Doe')
      end

      it 'returns the full name' do
        expect(admin_user.full_name).to eq('John Doe')
      end
    end

    context 'when names are nil' do
      before do
        admin_user.update(first_name: nil, last_name: nil)
      end

      it 'returns nil' do
        expect(admin_user.full_name).to be_nil
      end
    end
  end

  describe '#can_be_deleted?' do
    subject { admin_user.can_be_deleted? }

    context 'when store has other users with roles' do
      before { create(:admin_user) }

      it { is_expected.to be(true) }
    end

    context 'when admin user is the only one on the store' do
      it { is_expected.to be(false) }
    end
  end

  describe 'ransackable attributes' do
    it 'allows searching by id' do
      expect(Spree.admin_user_class.ransackable_attributes).to include('id')
    end

    it 'allows searching by email' do
      expect(Spree.admin_user_class.ransackable_attributes).to include('email')
    end

    it 'allows searching by first_name' do
      expect(Spree.admin_user_class.ransackable_attributes).to include('first_name')
    end

    it 'allows searching by last_name' do
      expect(Spree.admin_user_class.ransackable_attributes).to include('last_name')
    end
  end

  describe 'ransackable associations' do
    it 'allows searching by spree_roles' do
      expect(Spree.admin_user_class.ransackable_associations).to include('spree_roles')
    end
  end

  describe 'callbacks' do
    describe 'after_destroy' do
      let!(:other_admin_user) { create(:admin_user) }

      describe '#nullify_approver_id_in_approved_orders' do
        let!(:approved_order) { create(:order, approver: admin_user) }

        it 'nullifies approver_id on approved orders' do
          admin_user.destroy
          expect(approved_order.reload.approver_id).to be_nil
        end
      end

      describe '#cleanup_admin_user_resources' do
        let!(:canceled_order) { create(:order, canceler: admin_user, state: 'canceled') }
        let!(:created_order) { create(:order, created_by: admin_user) }
        let!(:gift_card) { create(:gift_card, created_by: admin_user) }
        let!(:gift_card_batch) { create(:gift_card_batch, created_by: admin_user, amount: 100, prefix: 'TEST') }
        let!(:refund) { create(:refund, refunder: admin_user, amount: 1) }
        let!(:reimbursement) { create(:reimbursement, performed_by: admin_user) }
        let!(:post) { create(:post, author: admin_user) }
        let!(:store_credit) { create(:store_credit, created_by: admin_user) }
        let!(:report) { create(:report, user: admin_user) }
        let!(:export) { create(:export, user: admin_user) }

        it 'nullifies canceler_id on canceled orders' do
          admin_user.destroy
          expect(canceled_order.reload.canceler_id).to be_nil
        end

        it 'nullifies created_by_id on created orders' do
          admin_user.destroy
          expect(created_order.reload.created_by_id).to be_nil
        end

        it 'nullifies created_by_id on gift cards' do
          admin_user.destroy
          expect(gift_card.reload.created_by_id).to be_nil
        end

        it 'nullifies created_by_id on gift card batches' do
          admin_user.destroy
          expect(gift_card_batch.reload.created_by_id).to be_nil
        end

        it 'nullifies refunder_id on refunds' do
          admin_user.destroy
          expect(refund.reload.refunder_id).to be_nil
        end

        it 'nullifies performed_by_id on reimbursements' do
          admin_user.destroy
          expect(reimbursement.reload.performed_by_id).to be_nil
        end

        it 'nullifies author_id on posts' do
          admin_user.destroy
          expect(post.reload.author_id).to be_nil
        end

        it 'nullifies created_by_id on store credits' do
          admin_user.destroy
          expect(store_credit.reload.created_by_id).to be_nil
        end

        it 'destroys reports' do
          expect { admin_user.destroy }.to change(Spree::Report, :count).by(-1)
        end

        it 'destroys exports' do
          expect { admin_user.destroy }.to change(Spree::Export, :count).by(-1)
        end
      end
    end
  end

  describe 'class configuration' do
    it 'uses a different class than Spree.user_class' do
      expect(Spree.admin_user_class).to eq(Spree::LegacyAdminUser)
      expect(Spree.user_class).to eq(Spree::LegacyUser)
      expect(Spree.admin_user_class).not_to eq(Spree.user_class)
    end

    it 'does not include UserMethods' do
      expect(Spree::LegacyAdminUser.included_modules).not_to include(Spree::UserMethods)
    end

    it 'includes AdminUserMethods' do
      expect(Spree::LegacyAdminUser.included_modules).to include(Spree::AdminUserMethods)
    end
  end

  describe 'avatar attachment' do
    it 'can attach an avatar' do
      admin_user.avatar.attach(
        io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
        filename: 'avatar.jpg',
        content_type: 'image/jpeg'
      )
      expect(admin_user.avatar).to be_attached
    end
  end

  describe 'roles integration' do
    it 'can have roles assigned' do
      role = create(:role, name: 'custom_role')
      admin_user.add_role('custom_role', current_store)
      expect(admin_user.has_spree_role?('custom_role', current_store)).to be(true)
    end

    it 'can check admin status' do
      expect(admin_user.spree_admin?(current_store)).to be(true)
    end
  end
end
