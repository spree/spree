module Spree
  module Admin
    module AssetsHelper
      def media_form_assets(viewable, viewable_type)
        if viewable&.persisted?
          viewable.images
        elsif session_uploaded_assets(viewable_type).any?
          Spree::Asset.accessible_by(current_ability, :manage).where(id: session_uploaded_assets(viewable_type))
        else
          []
        end
      end

      def ensure_session_uploaded_assets_uuid(viewable_type)
        session[session_uploaded_assets_uuid_key(viewable_type)] ||= SecureRandom.uuid
      end

      def store_uploaded_asset_in_session(asset, viewable_type)
        ensure_session_uploaded_assets_uuid(viewable_type)
        asset.update(session_id: session[session_uploaded_assets_uuid_key(viewable_type)])
      end

      def session_uploaded_assets(viewable_type)
        return Spree::Asset.none if session[session_uploaded_assets_uuid_key(viewable_type)].blank?

        Spree::Asset.with_session_uploaded_assets_uuid(session[session_uploaded_assets_uuid_key(viewable_type)]).where(viewable_id: nil)
      end

      def clear_session_for_uploaded_assets(viewable_type)
        session.delete(session_uploaded_assets_uuid_key(viewable_type))
      end

      def session_uploaded_assets_uuid_key(viewable_type)
        [
          'spree.admin.uploaded_assets',
          viewable_type&.underscore,
          'uuid'
        ].compact_blank.join('.')
      end
    end
  end
end
