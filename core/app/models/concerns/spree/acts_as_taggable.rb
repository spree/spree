module Spree
  module ActsAsTaggable
    extend ActiveSupport::Concern

    included do
      acts_as_taggable
      Spree::PermittedAttributes.send("#{model_name.param_key}_attributes") <<
        [:tag_list]
    end
  end
end
