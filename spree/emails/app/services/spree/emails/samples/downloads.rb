module Spree
  module Emails
    module Samples
      # The files-ready email. Lists the order's own downloads when it has any,
      # always with placeholder links.
      class Downloads < Order
        def variables
          {
            order: data(record, Spree::Emails::OrderSerializer),
            downloads: downloads,
            resend: false
          }
        end

        private

        def downloads
          links = record.digital_links.includes(digital_asset: { attachment_attachment: :blob }).to_a
          return [{ filename: 'guide.pdf', url: placeholder_url('downloads'), expires_at: nil }] if links.empty?

          links.map do |link|
            { filename: link.filename.to_s, url: placeholder_url('downloads'), expires_at: link.expires_at&.iso8601 }
          end
        end
      end
    end
  end
end
