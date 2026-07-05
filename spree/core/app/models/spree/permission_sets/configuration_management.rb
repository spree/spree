# Permission set for managing store configuration and settings.
#
# This permission set provides access to manage store settings,
# payment methods, shipping methods, and other configuration.
#
# @example
#   Spree.permissions.assign(:store_admin, Spree::PermissionSets::ConfigurationManagement)
#
module Spree
  module PermissionSets
    class ConfigurationManagement < Base
      def activate!
        # Store settings
        can :manage, Spree::Store

        # Payment configuration
        can :manage, Spree::PaymentMethod
        can :manage, Spree::Gateway

        # Shipping configuration
        can :manage, Spree::ShippingMethod
        can :manage, Spree::ShippingCategory
        can :manage, Spree::Zone
        can :manage, Spree::ZoneMember

        # Markets — Channel / Market is the long-term replacement for
        # Zone (see docs/plans/6.0-tax-provider.md), but both coexist
        # during the migration and need admin read/write either way.
        can :manage, Spree::Market

        # Tax configuration
        can :manage, Spree::TaxCategory
        can :manage, Spree::TaxRate

        # CORS allowlist used by Rack::Cors + admin cookie auth (see
        # docs/plans/5.5-admin-auth-cookie-refresh.md).
        can :manage, Spree::AllowedOrigin

        # Webhooks
        can :manage, Spree::WebhookEndpoint
        can :manage, Spree::WebhookDelivery

        # General configuration
        can :manage, Spree::RefundReason
        can :manage, Spree::ReimbursementType
        can :manage, Spree::ReturnReason

        # Channels
        can :manage, Spree::Channel

        # Restrictions on immutable types
        cannot [:edit, :update], Spree::RefundReason, mutable: false
        cannot [:edit, :update], Spree::ReimbursementType, mutable: false

        # Metafield configuration
        can :manage, Spree::MetafieldDefinition

        # Policies
        can :manage, Spree::Policy
      end
    end
  end
end
