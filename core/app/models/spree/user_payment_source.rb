module Spree
  class UserPaymentSource < ActiveRecord::Base
    after_save :ensure_one_default

    belongs_to :user, class_name: Spree.user_class, foreign_key: 'user_id'
    belongs_to :payment_source, polymorphic: true

    private

    def ensure_one_default
      if self.user_id && self.default
        self.class.where(default: true).where.not(id: self.id).where(user_id: self.user_id).each do |ucc|
          ucc.update_columns(default: false)
        end
      end
    end
  end
end
