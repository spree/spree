module Spree
  class StoreCreditEvent < Spree.base_class
    acts_as_paranoid

    belongs_to :store_credit
    belongs_to :originator, polymorphic: true

    scope :exposed_events, -> { where.not(action: [Spree::StoreCredit::ELIGIBLE_ACTION, Spree::StoreCredit::AUTHORIZE_ACTION]) }
    scope :reverse_chronological, -> { order(created_at: :desc) }

    delegate :currency, :store, to: :store_credit

    extend DisplayMoney
    money_methods :amount, :user_total_amount

    def display_action
      case action
      when Spree::StoreCredit::CAPTURE_ACTION
        Spree.t('store_credit.captured')
      when Spree::StoreCredit::AUTHORIZE_ACTION
        Spree.t('store_credit.authorized')
      when Spree::StoreCredit::ALLOCATION_ACTION
        Spree.t('store_credit.allocated')
      when Spree::StoreCredit::VOID_ACTION, Spree::StoreCredit::CREDIT_ACTION
        Spree.t('store_credit.credit')
      end
    end

    def order
      store.payments.find_by(response_code: authorization_code).try(:order)
    end

    def allocation?
      action == Spree::StoreCredit::ALLOCATION_ACTION
    end

    def credit?
      action == Spree::StoreCredit::CREDIT_ACTION
    end

    def captured?
      action == Spree::StoreCredit::CAPTURE_ACTION
    end

    def voided?
      action == Spree::StoreCredit::VOID_ACTION
    end

    def authorized?
      action == Spree::StoreCredit::AUTHORIZE_ACTION
    end
  end
end
