module Spree
  module Admin
    module SessionAssetsHelper
      def ensure_session_uploaded_assets_uuid
        session['spree.admin.uploaded_assets.uuid'] ||= SecureRandom.uuid
      end

      def store_uploaded_asset_in_session(asset)
        ensure_session_uploaded_assets_uuid
        asset.update(session_id: session['spree.admin.uploaded_assets.uuid'])
      end

      def session_uploaded_assets
        return Spree::Asset.none if session['spree.admin.uploaded_assets.uuid'].blank?

        Spree::Asset.with_session_uploaded_assets_uuid(session['spree.admin.uploaded_assets.uuid']).where(viewable_id: nil)
      end

      def clear_session_for_uploaded_assets
        session.delete('spree.admin.uploaded_assets.uuid')
      end
    end
  end
end
