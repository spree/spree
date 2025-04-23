module Spree
  module UniqueName
    extend ActiveSupport::Concern

    included do
      auto_strip_attributes :name

      validates :name, presence: true,
                       uniqueness: { case_sensitive: false, allow_blank: true, scope: spree_base_uniqueness_scope }
    end
  end
end
