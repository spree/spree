# Temporary fix to FriendlyId in Rails5, so that we don't
# encounter any validation errors when creating slugs via
# FriendlyId::History on a paranoid model.
# See: https://github.com/norman/friendly_id/issues/822
if Rails::VERSION::STRING >= '5.0'
  module FriendlyId
    class Slug < ActiveRecord::Base
      belongs_to :sluggable, polymorphic: true, optional: true
    end
  end
end
