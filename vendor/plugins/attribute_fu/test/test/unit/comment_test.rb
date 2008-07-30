require File.dirname(__FILE__) + '/../test_helper'

class CommentTest < ActiveSupport::TestCase
  should_belong_to :photo
  should_require_attributes :author, :body
end
