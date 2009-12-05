require 'active_record'              
#require 'test/unit/testcase'

def assert (bool,msg)
  puts "#{bool ? "OK   =>" : "FAIL =>"} #{msg}"
end

namespace :db do
  desc "check overall database consistency"
  task :consistency => :environment do
  end
        
  namespace :consistency do                       
    desc "Check product and variant consistency" 
    task :products => :environment do
      assert(Product.all.all? {|p| p.master.present?},
             "all products must have a master variant")
      assert(Product.all.all? {|p| p.master.option_values.empty?}, 
             "all master variants must have no option values")
      assert(Product.all.all? {|p| p.variants.all? {|v| ! v.option_values.empty?}},
             "all (non-master) variants must have some option values")
      
      o_types = Product.all(:include => {:variants => :option_values}).all? do |p| 
                  v_types = p.variants.map {|v| v.option_values.map &:option_type}.flatten.uniq 
                  v_types.map(&:id).sort == p.option_types.map(&:id).sort
                end
      assert(o_types, "a product's option types must match the types on its variants' options")
    end
  end
end
