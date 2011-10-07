class Spree::LogEntry < ActiveRecord::Base
  belongs_to :source, :polymorphic => true
end
