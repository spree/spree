# direct method cannot be used inside engine routes
# see: https://github.com/rails/rails/issues/34872
Rails.application.routes.draw do
  direct :cdn_image do |model, options|
    opts = options.slice(:protocol, :port)
    opts[:host] = Spree.cdn_host.presence ||
                  Rails.application.routes.default_url_options[:host].presence ||
                  options[:host].presence ||
                  (Spree::Store.current.present? ? Spree::Store.current.formatted_url : nil)
    opts[:only_path] = true if opts[:host].blank?

    if model.blob.service_name == 'cloudinary' && defined?(Cloudinary)
      if model.class.method_defined?(:has_mvariation)
        Cloudinary::Utils.cloudinary_url(model.blob.key,
          width: model.variation.transformations[:resize_to_limit].first,
          height: model.variation.transformations[:resize_to_limit].last,
          crop: :fill
        )
      else
        Cloudinary::Utils.cloudinary_url(model.blob.key)
      end
    elsif model.respond_to?(:signed_id)
      route_for(
        :rails_service_blob_proxy,
        model.signed_id,
        model.filename,
        opts
      )
    else
      signed_blob_id = model.blob.signed_id
      variation_key  = model.variation.key
      filename       = model.blob.filename

      route_for(
        :rails_blob_representation_proxy,
        signed_blob_id,
        variation_key,
        filename,
        opts
      )
    end
  end
  # Used by admin mailers; the SPA derives the URL from `window.location.origin` instead.
  #
  # Which app the link opens follows what the invitation is *to*. An
  # invitation onto a seller has to land on the seller panel: the dashboard's
  # acceptance page authenticates through the Admin API, which no seller may
  # call, so a seller sent there could read the invitation and never accept it.
  direct :admin_invitation_acceptance do |invitation, _options = {}|
    path = "/accept-invitation/#{invitation.prefixed_id}?token=#{invitation.token}"
    base = if invitation.resource.is_a?(Spree::Seller)
             Spree::Sellers::PanelUrl.call(store: invitation.store)
           else
             Spree::Stores::DashboardUrl.call(store: invitation.store)
           end

    base.present? ? "#{base}#{path}" : path
  end
end

Spree::Core::Engine.draw_routes
