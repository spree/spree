module Spree
  class LogEntry < ActiveRecord::Base
    belongs_to :source, :polymorphic => true

    attr_accessible :details
  end
end
