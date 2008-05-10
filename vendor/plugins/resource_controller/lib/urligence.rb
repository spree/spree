module Urligence
  def smart_url(*objects)
    urligence(*objects.push(:url))
  end
  
  def smart_path(*objects)
    urligence(*objects.push(:path))
  end
  
  def hash_for_smart_url(*objects)
    urligence(*objects.unshift(:hash_for).push(:url).push({:type => :hash}))
  end
  
  def hash_for_smart_path(*objects)
    urligence(*objects.unshift(:hash_for).push(:path).push({:type => :hash}))
  end
  
  def urligence(*objects)
    config = {}
    config.merge!(objects.pop) if objects.last.is_a?(Hash)
    
    objects.reject! { |object| object.nil? }
    
    url_fragments = objects.collect do |obj|
      if obj.is_a? Symbol
        obj
      elsif obj.is_a? Array
        obj.first
      else
        obj.class.name.underscore.to_sym
      end
    end
    
    unless config[:type] == :hash
      send url_fragments.join("_"), *objects.flatten.select { |obj| !obj.is_a? Symbol }
    else
      params = {}
      unparsed_params = objects.select { |obj| !obj.is_a? Symbol }
      unparsed_params.each_with_index do |obj, i|
        unless i == (unparsed_params.length-1)
          params.merge!((obj.is_a? Array) ? {"#{obj.first}_id".to_sym => obj[1].to_param} : {"#{obj.class.name.underscore}_id".to_sym => obj.to_param})
        else
          params.merge!((obj.is_a? Array) ? {:id => obj[1].to_param} : {:id => obj.to_param})
        end
      end
      
      send url_fragments.join("_"), params
    end
  end
end
