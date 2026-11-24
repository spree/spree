module Spree
  module Api
    module V3
      module Admin
        # What publishing products on, or unpublishing them from, channels did.
        class BulkProductChannelsResultSerializer < BulkProductResultSerializer
          typelize channel_count: [:number, comment: 'Channels the action applied to'],
                   removed: [:number, optional: true, comment: 'Publications removed. Present when unpublishing.']

          attributes :channel_count

          attribute :removed, if: proc { |result| result.key?(:removed) } do |result|
            result[:removed]
          end
        end
      end
    end
  end
end
