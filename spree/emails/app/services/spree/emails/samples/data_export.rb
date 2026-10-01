module Spree
  module Emails
    module Samples
      class DataExport < Base
        def variables
          { download_url: placeholder_url('account/data-export'), expires_at: 7.days.from_now.iso8601 }
        end
      end
    end
  end
end
