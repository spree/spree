module Scopes::Variant
  # WARNING tested only under sqlite and postgresql
  Variant.named_scope :descend_by_popularity, lambda{
    {
      :order => 'COALESCE((SELECT COUNT(*) FROM  line_items GROUP BY line_items.variant_id HAVING line_items.variant_id = variants.id), 0) DESC'
    }
  }
  
end
