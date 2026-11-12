module Spree
  module Api
    module V3
      # Where a presigned upload sends its bytes. Clients send them with
      # `method` to `url` carrying exactly `headers`, and treat all three as
      # opaque: the storage service decides them.
      class FileUploadTargetSerializer < BaseSerializer
        _attributes.delete(:id)

        typelize method: :string, url: :string, headers: 'Record<string, string>'

        attribute :method, &:http_method
        attributes :url, :headers
      end
    end
  end
end
