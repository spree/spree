module Spree
  class StateChange < Spree.base_class
    belongs_to :user, class_name: "::#{Spree.user_class}", optional: true
    belongs_to :stateful, polymorphic: true

    def <=>(other)
      created_at <=> other.created_at
    end
  end
end
