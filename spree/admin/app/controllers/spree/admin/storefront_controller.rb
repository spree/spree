# frozen_string_literal: true

module Spree
  module Admin
    class StorefrontController < BaseController
      include Spree::Admin::SettingsConcern

      # GET /admin/storefront
      def show
        @breadcrumb_icon = 'building-store'
        add_breadcrumb Spree.t('admin.storefront_setup.title'), spree.admin_storefront_path

        @publishable_key = find_or_create_publishable_key
        @deployment_origin = normalize_origin(params[:'deployment-url'])
        @deployment_origin_allowed = @deployment_origin.present? && current_store.allowed_origin?(@deployment_origin)
        @vercel_dashboard_url = vercel_dashboard_url
        @storefront_origins = current_store.allowed_origins.order(:created_at).reject(&:loopback?)
      end

      # PATCH /admin/storefront
      #
      # Saves the storefront URL preference (used as the base for links in
      # customer emails and as the "connected" signal for non-web storefronts),
      # optionally adding it as an allowed origin for browser-based storefronts.
      def update
        origin = normalize_origin(params[:storefront_url])

        if origin.nil?
          flash[:error] = Spree.t('admin.storefront_setup.invalid_origin')
        else
          current_store.update!(preferred_storefront_url: origin)
          current_store.allowed_origins.find_or_create_by(origin: origin) if params[:add_allowed_origin] == '1'
          flash[:success] = Spree.t('admin.storefront_setup.storefront_url_saved', url: origin)
        end

        redirect_to spree.admin_storefront_path, status: :see_other
      end

      # POST /admin/storefront/allow_origin
      def allow_origin
        origin = normalize_origin(params[:origin])

        if origin.nil?
          flash[:error] = Spree.t('admin.storefront_setup.invalid_origin')
        else
          allowed_origin = current_store.allowed_origins.find_or_initialize_by(origin: origin)

          if allowed_origin.persisted? || allowed_origin.save
            current_store.update(preferred_storefront_url: origin) if current_store.preferred_storefront_url.blank?
            flash[:success] = Spree.t('admin.storefront_setup.origin_allowed', origin: origin)
          else
            flash[:error] = allowed_origin.errors.full_messages.to_sentence
          end
        end

        redirect_to spree.admin_storefront_path, status: :see_other
      end

      private

      # Every action here is store configuration (publishable keys, allowed
      # origins, store preferences), so gate the whole page behind store
      # management — granted by e.g. Spree::PermissionSets::ConfigurationManagement.
      def authorize_admin
        authorize! :admin, Spree::Store
        authorize! :update, current_store
      end

      # The storefront needs a publishable key; reuse the oldest active one
      # (usually the seeded "Default") and mint one for stores that have none.
      def find_or_create_publishable_key
        current_store.api_keys.active.publishable.order(:created_at).first ||
          current_store.api_keys.create!(
            name: 'Storefront',
            key_type: 'publishable',
            created_by: try_spree_current_user
          )
      end

      # Normalizes user or Vercel-callback input (possibly a bare host like
      # my-shop.vercel.app) to a canonical origin string (scheme://host[:port]),
      # or nil when it's not a valid http(s) URL.
      def normalize_origin(raw)
        raw = raw.to_s.strip
        return if raw.blank?

        candidate = raw.match?(%r{\Ahttps?://}i) ? raw : "https://#{raw}"
        parsed = Spree::AllowedOrigin.parse_origin(candidate)
        return if parsed.nil?

        origin = "#{parsed[:scheme]}://#{parsed[:host]}"
        origin += ":#{parsed[:port]}" unless [80, 443].include?(parsed[:port])
        origin
      end

      # Only link back to the Vercel dashboard when the callback param actually
      # points at vercel.com — never reflect an arbitrary URL as a link.
      def vercel_dashboard_url
        url = params[:'project-dashboard-url'].to_s
        parsed = Spree::AllowedOrigin.parse_origin(url)
        return unless parsed && parsed[:scheme] == 'https'

        url if parsed[:host] == 'vercel.com' || parsed[:host].end_with?('.vercel.com')
      end
    end
  end
end
