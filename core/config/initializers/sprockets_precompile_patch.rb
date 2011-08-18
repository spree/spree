require 'sprockets/asset_attributes'

Sprockets::AssetAttributes.class_eval do
  alias_method :sprockets_path_with_fingerprint, :path_with_fingerprint

  # hack to allow precompiling assets for development mode
  # stops sprockets adding the fingerprint to the file name
  def path_with_fingerprint(digest)
    if Rails.env.development?
      pathname.to_s
    else
      sprockets_path_with_fingerprint(digest)
    end
  end

end
