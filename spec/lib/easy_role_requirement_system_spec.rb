require File.dirname(__FILE__) + '/../spec_helper.rb'


class Control0Controller < ActionController::Base
  #include AuthenticatedSystem
  include RoleRequirementSystem
  
  def index;end
  def show;end
  def comp;end
end

class Control1Controller < Control0Controller
  reset_role_requirements!
  require_role :admin, :only => [:index, :show]      
end

class Control2Controller < Control1Controller
  reset_role_requirements!
  require_role :admin, :except => [:index, :ship, :show], :if  => "false"
end

class Control3Controller < Control2Controller
  reset_role_requirements!
  require_role :admin, :except => [:index, :show], :unless =>"true"
end

class Control4Controller < Control3Controller
end

class Control5Controller < Control4Controller
  reset_role_requirements!
  require_role :admin, :only => [:comp] 
end

class Control6Controller < Control5Controller
end

class Control7Controller < Control6Controller
  reset_role_requirements!
  require_role [:shipper, :admin]  
  require_role :admin, :except => [:index, :show]
end

def define_classes
  original_class_name, parent_name = 'EasyRolesTest', 'ActionController::Base'
  classes = []
  @class_names = []
  
  8.times do |n|
    class_name = original_class_name.dup << "#{n}" << "Controller"
    @class_names << class_name
    
    class_doc = <<-CLASS_DOC
    class #{class_name} < #{parent_name}
      
    # All this hokus pokus just overrides the actual @permissions_file for the app 
    # and prevents it from being read into the module. Also it only includes the modules
    # in the parent of our EasyRolesTest Class hierarchy (below ActionController::Base). 
    
    if self.to_s == "EasyRolesTest0Controller"
      @permissions_file = YAML.load(create_permissions)
      #include AuthenticatedSystem
      include RoleRequirementSystem     
      include EasyRoleRequirementSystem 
    end

    if self.to_s =~ /EasyRolesTest/
      def self.inherited(sub_klass)
        @permissions_file = YAML.load(create_permissions)
        sub_klass.class_eval("@permissions_file = YAML.load(create_permissions)")       
        sub_klass.reset_role_requirements! if sub_klass.has_role_requirements?
        sub_klass.enforce_permissions
      end
    end
    
    end
    CLASS_DOC

    classes << class_doc
    parent_name = class_name
  end
  classes  
end

def create_permissions     
  test_permissions_doc = <<-YAML_END 
  'EasyRolesTest1Controller':
    permission1:
      role : [admin]
      options :
        only : [index, show]        
  'EasyRolesTest2Controller':
    permission1:
      role : [admin]
      options :
        except : [index, ship, show]
        if : "false"
  'EasyRolesTest3Controller':
    permission1:
      role : [admin]
      options :
        except : [index, show]
        unless : "true"
# No Values For EasyRolesTest4Controller
  'EasyRolesTest5Controller':
    permission1:
      role : [admin]
      options :
        only : comp
# No Values For EasyRolesTest6Controller
  'EasyRolesTest7Controller':
    permission1:
      roles : [shipper, admin] 
    permission2:
      role : [admin]
      options :
        except : [index, show]
  YAML_END
end

def create_classes
  classes = define_classes
  classes.each {|klass| eval(klass)}    
end
  
create_classes
index = 0

@class_names.each do |class_name|
  describe class_name do 
    control_class_name = "Control#{index}Controller"
         
    it "#{class_name} should have the same permissions as #{control_class_name}" do
      eval(class_name).role_requirements.should ==
      eval(control_class_name).role_requirements
    end
  end
  index += 1
end