module Spree
  class SettingsController < Spree::StoreController
    def show; end

    def update
      new_locale = (params[:switch_to_locale] || params[:locale]).to_s
      new_currency = params[:switch_to_currency]&.upcase

      if new_currency.present? && supported_currency?(new_currency)
        current_order&.update(currency: new_currency)
        session[:currency] = new_currency
      end

      if new_locale.present? && supported_locale?(new_locale)
        if try_spree_current_user && try_spree_current_user.selected_locale != new_locale
          try_spree_current_user.update!(selected_locale: new_locale)
        end

        locale_for_slug = new_locale
        new_locale = nil if new_locale.to_s == current_store.default_locale.to_s

        if request.referer.present?
          uri = URI(request.referer)

          previous_params = begin
            Spree::Core::Engine.routes.recognize_path(uri.path)
          rescue ActionController::RoutingError
            Rails.application.routes.recognize_path(uri.path)
          end

          redirect_to spree.root_path(locale: new_locale) && return if previous_params.blank?

          new_params = previous_params.clone.merge(locale: new_locale)

          # We only care if the previous url was for a specific record, because we need to find it with the slug/permalink from the new locale
          new_params[:id] = find_slug_in_current_locale(previous_params, locale_for_slug)

          redirect_to new_params
        else
          redirect_to spree.root_path(locale: new_locale)
        end
      else
        redirect_to spree.root_path
      end
    end

    private

    def find_slug_in_current_locale(params, new_locale)
      if params[:id].present?
        case params[:controller]
        when 'spree/products'
          old_product = find_with_fallback(params[:locale]) { current_store.products.friendly.find(params[:id]) }
          old_product.slug(locale: new_locale) || old_product.slug(locale: current_store.default_locale)
        when 'spree/taxons'
          old_taxon = find_with_fallback(params[:locale]) { current_store.taxons.friendly.find(params[:id]) }
          old_taxon.permalink(locale: new_locale) || old_taxon.permalink(locale: current_store.default_locale)
        else
          params[:id]
        end
      end
    end

    def find_with_fallback(locale, &block)
      Mobility.with_locale(locale) { find_with_fallback_default_locale(&block) }
    end
  end
end
