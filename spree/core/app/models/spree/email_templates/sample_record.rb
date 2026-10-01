module Spree
  module EmailTemplates
    # A record of the store an email can be previewed with, as the editor's
    # record picker lists it.
    class SampleRecord
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :id, :string
      attribute :label, :string
      attribute :created_at, :datetime

      alias prefixed_id id
    end
  end
end
