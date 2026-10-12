module Spree
  module Api
    module V3
      module Admin
        # What the last update check found (Spree::UpdateStatus). A computed
        # value rather than a record, so it carries no id.
        class UpdateStatusSerializer < V3::BaseSerializer
          typelize current_version: :string,
                   enabled: :boolean,
                   update_available: :boolean,
                   latest_version: [:string, nullable: true],
                   latest_release_url: [:string, nullable: true],
                   latest_release_published_at: [:string, nullable: true],
                   checked_at: [:string, nullable: true]

          _attributes.delete(:id)

          attributes :current_version, :enabled, checked_at: :iso8601

          attribute(:update_available) { |status| status.update_available? }
          attribute(:latest_version) { |status| status.latest_release&.dig(:version) }
          attribute(:latest_release_url) { |status| status.latest_release&.dig(:url) }
          attribute(:latest_release_published_at) { |status| status.latest_release&.dig(:published_at)&.iso8601(3) }
        end
      end
    end
  end
end
