# direct method cannot be used inside engine routes
# see: https://github.com/rails/rails/issues/34872
Rails.application.routes.draw do
  direct :cdn_image do |model, options|
    opts = options.slice(:protocol, :host, :port)
    opts[:host] = Spree.cdn_host if Spree.cdn_host.present?
    opts[:host] ||= Rails.application.routes.default_url_options[:host]
    opts[:host] ||= Spree::Store.current.url_or_custom_domain if Spree::Store.current.present?

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
  direct :admin_invitation_acceptance do |invitation, _options = {}|
    path = "/accept-invitation/#{invitation.prefixed_id}?token=#{invitation.token}"
    base = Spree::Config[:admin_url].presence ||
           (Rails.env.development? ? 'http://localhost:5173' : nil) ||
           invitation.store&.formatted_url

    base.present? ? "#{base.chomp('/')}#{path}" : path
  end
end

Spree::Core::Engine.draw_routes
