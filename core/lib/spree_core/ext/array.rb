# RAILS3 TODO (likely not needed - it was commented out before rails3 branch)
# module SpreeCore::Ext::Array
#   def to_hash_keys(&block)
#     Hash[*self.collect { |v|
#       [v, block.call(v)]
#     }.flatten]
#   end
#
#   def to_hash_values(&block)
#     Hash[*self.collect { |v|
#       [block.call(v), v]
#     }.flatten]
#   end
# end