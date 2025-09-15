module Spree
  module AdminUserMethods
    extend ActiveSupport::Concern

    included do
      # Associations
      has_many :canceled_orders, class_name: 'Spree::Order', foreign_key: :canceler_id
      has_many :created_orders, class_name: 'Spree::Order', foreign_key: :created_by_id
      has_many :approved_orders, class_name: 'Spree::Order', foreign_key: :approver_id
      has_many :created_gift_cards, class_name: 'Spree::GiftCard', foreign_key: :created_by_id
      has_many :created_gift_card_batches, class_name: 'Spree::GiftCardBatch', foreign_key: :created_by_id
      has_many :refunded_refunds, class_name: 'Spree::Refund', foreign_key: :refunder_id
      has_many :performed_reimbursements, class_name: 'Spree::Reimbursement', foreign_key: :performed_by_id
      has_many :authored_posts, class_name: 'Spree::Post', foreign_key: :author_id
      has_many :created_store_credits, class_name: 'Spree::StoreCredit', foreign_key: :created_by_id
      has_many :reports, class_name: 'Spree::Report', foreign_key: :user_id
      has_many :exports, class_name: 'Spree::Export', foreign_key: :user_id

      # Callbacks
      before_destroy :check_if_there_are_other_admin_users
      after_destroy :nullify_approver_id_in_approved_orders
      after_destroy :cleanup_admin_user_resources
    end

    private

    def nullify_approver_id_in_approved_orders
      return if self.class != Spree.admin_user_class

      approved_orders.update_all(approver_id: nil, updated_at: Time.current)
    end

    def cleanup_admin_user_resources
      return if self.class != Spree.admin_user_class

      # resources to nullify
      # TODO: we should change these associations to polymorphic and resolve this via standard rails association
      # declarations with dependent: :nullify
      canceled_orders.update_all(canceler_id: nil, updated_at: Time.current)
      created_orders.update_all(created_by_id: nil, updated_at: Time.current)
      created_gift_cards.update_all(created_by_id: nil, updated_at: Time.current)
      created_gift_card_batches.update_all(created_by_id: nil, updated_at: Time.current)
      refunded_refunds.update_all(refunder_id: nil, updated_at: Time.current)
      performed_reimbursements.update_all(performed_by_id: nil, updated_at: Time.current)
      authored_posts.update_all(author_id: nil, updated_at: Time.current)
      created_store_credits.update_all(created_by_id: nil, updated_at: Time.current)

      # resources to destroy
      reports.destroy_all
      exports.destroy_all
    end

    def check_if_there_are_other_admin_users
      return if self.class != Spree.admin_user_class
      return unless has_spree_role?(Spree::Role::ADMIN_ROLE)

      if Spree::Store.current.users.where.not(id: id).none?
        errors.add(:base, I18n.t('activerecord.errors.models.spree/admin_user.attributes.base.cannot_destroy_last_admin_user'))
        throw(:abort)
      end
    end
  end
end
