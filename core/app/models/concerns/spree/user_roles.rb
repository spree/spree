module Spree
  module UserRoles
    extend ActiveSupport::Concern

    included do
      has_many :role_users, class_name: 'Spree::RoleUser', foreign_key: :user_id, dependent: :destroy
      has_many :spree_roles, through: :role_users, class_name: 'Spree::Role', source: :role

      scope :spree_admin, -> { joins(:spree_roles).where(Spree::Role.table_name => { name: 'admin' }) }

      # has_spree_role? simply needs to return true or false whether a user has a role or not.
      def has_spree_role?(role_name)
        spree_roles.exists?(name: role_name)
      end

      def self.admin
        ActiveSupport::Deprecation.warn('`User#admin` is deprecated and will be removed in Spree 5. Please use `User#spree_admin`')

        spree_admin
      end

      def self.admin_created?
        ActiveSupport::Deprecation.warn('`User#admin_created?` is deprecated and will be removed in Spree 5. Please use `User#spree_admin_created?`')

        spree_admin_created?
      end

      def admin?
        ActiveSupport::Deprecation.warn('`User#admin?` is deprecated and will be removed in Spree 5. Please use `User#spree_admin?`')

        spree_admin?
      end

      def self.spree_admin_created?
        spree_admin.exists?
      end

      def spree_admin?
        has_spree_role?('admin')
      end
    end
  end
end
