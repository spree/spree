# Copyright (c) 2007-2008, Paul Saieg
# All rights reserved.

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:

#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright notice,
#       this list of conditions and the following disclaimer in the documentation
#       and/or other materials provided with the distribution.
#     * Neither the name of the Paul Saieg nor may be used to endorse or
#       promote products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
require 'spree'
module EasyRoleRequirementSystem
  def self.included(klass)
    super
    klass.extend ClassMethods
    klass.enforce_permissions

    def klass.inherited(sub_klass)
      super
      sub_klass.reset_role_requirements!
      sub_klass.enforce_permissions
    end
  end


  module InstanceMethods
    def included(klass)
      raise "Include RoleRequirementSystem first BEFORE including EasyRoleRequirementSystem." unless klass.included_modules.include?(RoleRequirementSystem)
    end
  end

  include InstanceMethods

  module ClassMethods
    def role_permissions_file_path
      @role_permissions_file_path ||= "#{Rails.root}/config/spree_permissions.yml"
    end

    def has_role_requirements?
      self.role_requirements && self.role_requirements != [] ? true : false
    end

    # calls RoleRequirementSystem::require_role for every permission set in the
    # config file for the current controller
    def enforce_permissions
       controller_permissions.each do |permission|
         all_parameters = []
         permission.each do |p|
           check_format(p)
           parameter = {}
           parameter[:roles]   = add_roles(p)
           parameter[:options] = (reformat_options(p[:options]) if p[:options]) || {}
           all_parameters << parameter
         end
         all_parameters.each{|param| self.require_role(param[:roles], param[:options]) \
           if param[:roles]}
       end
    end

  private
    # walks up the class ancestry to find the nearest defined role_requirements.
    # returns those requirements or {}
    def inherited_permissions(klass = self)
      super_class = klass.superclass
      if super_class.respond_to?(:has_role_requirements?) &&
         super_class.has_role_requirements?
           {'permission00' => super_class.role_requirements.last}
      elsif super_class.respond_to?(:has_role_requirements?)
          inherited_permissions(super_class)
      else
          {}
      end
    end

    def check_format(permission)
      legal_keys = [:role, :roles, :options]
      illegal_keys = permission.reject {|key, val| legal_keys.include?(key)}
      raise "Improperly formatted permission #{permission.inspect}. The following keys are illegal: #{illegal_keys.inspect}" if illegal_keys != {}
    end

    # Enforces permission formatting, gets permissions for controller. If none are
    # defined, it gets them from the controller's nearest parent who has them defined.
    # this gives the illusion of inherited permissions
    def controller_permissions
      permissions = []
      permission_format = /permission\d+/
      @permissions = all_permissions[self.to_s] || inherited_permissions
      @permissions.each_pair do |key, value|
        value = symbolize_keys(value)
        if key =~ permission_format && (value.has_key?(:roles) || value.has_key?(:role))
          permissions.push([value])
        else
          raise "Incorrectly formatted permission: #{{key => value}.inspect}. Permission line must match #{permission_format.inspect}. Permission also must contain one 'role:' or 'roles:' node."
        end
      end
      permissions
    end

    def symbolize_keys(hash)
      rehash = {}
      hash.each_pair {|key, value| rehash[key.to_sym] = value}
      rehash
    end

    # sets permissions for class from the permissions file (if it is mentioned ther)
    # or from default if it is not. The default is no restrictions at all.
    def all_permissions
      @permissions_file ||= load_permissions_file
      @permissions_file.has_key?(self.to_s) ? @permissions_file : no_permissions
    end

    # raises an error if permissions file is not loaded or child nodes got deleted
    # during YAML serialization
    def load_permissions_file
      begin
        permissions_file = YAML.load_file(role_permissions_file_path)
       # raise unless permissions_file && yaml_loaded_correctly(permissions_file)
        rescue
          raise "#{__FILE__ }: #{__LINE__}: in 'all_permissions': YAML Could not load role pemissions file at '#{role_permissions_file_path}', check the file location and YAML formatting. Duplicate YAML nodes may have been deleted during serialization."
      end
      #load_extension_permissions_files(permissions_file)
    end



    def merge_permissions_files(permissions_file, new_permissions_file)
      new_permissions_file.keys.each{|pf_key|
          if permissions_file.has_key?(pf_key)
            new_permissions_file[pf_key].keys.each{|p_key|
              permissions_file[pf_key][p_key] = new_permissions_file[pf_key][p_key]
              }
          else
            permissions_file[pf_key] = new_permissions_file[pf_key]
          end
        }
    end

    # make sure nothing is deleted in serialization
    def yaml_loaded_correctly(permissions_file)
      # scans a raw dump of the YAML file for entered values
      number_of_value_nodes_in_file =
      YAML.dump(YAML.parse_file(role_permissions_file_path)).scan(/\s*value:\s*\w/).length

      # scans an inspect string of the hash for entered values, each value is "quoted".
      number_of_value_nodes_in_hash =
        permissions_file.inspect.scan(/"/).length / 2
      number_of_value_nodes_in_hash == number_of_value_nodes_in_file
    end

    # default no permissions YAML doc
    def no_permissions
      no_permissions_doc = <<-YAML_END
      NoControllerHere:
        permission0:
            roles:
            options:
      YAML_END

      YAML.load(no_permissions_doc)
    end

    # Allows for either "roles:" or "role:" syntax in config file
    def add_roles(permission)
      roles = []
      role_key = has_role_node(permission)
      if role_key == :role
        permission[:roles] = permission[role_key].dup
        permission.delete role_key
        role_key = :roles
      end
      if permission[role_key].is_a?(Array)
        permission[role_key].each do |role|
          role = fix_comma_errors(role)
          role.each {|r| roles << r}
        end
      else
        fix_comma_errors(permission[role_key]).each do |other_role|
          other_role.each {|r| roles << r}
        end
      end
       result = roles.compact
       (result != [] && result != [{}]) ? result : nil
    end

    # YAML interperts [admin,user] as ["admin,user"]. This corrects YAMLs default
    # behaviour by changing ["admin,user"] to ["admin","user"]
    def fix_comma_errors(field)
      field.is_a?(Array) ?  field.map {|f| split_fields(f)} : split_fields(field)
    end

    def split_fields(field)
      field = field.to_s.gsub(/\s+?/, '')
      field.include?(',') ? symbolize_values(field.split(',')) : symbolize_values([field])
    end

    def symbolize_values(array)
      array.map {|val| val.to_s.to_sym}
    end

    # Tells us whether the permissions defines a 'roles:' or 'role:' node.
    # returns first encountered node (always 'roles' before'role') - never both.
    def has_role_node(permission)
      roles = [:roles,:role].map {|key| key if permission.has_key?(key)}.compact
      case
        when roles.length == 1 then roles[0]
      else
        raise "Improper Role Configuration: Permission has more than one role/roles node (nodes are #{roles.inspect}. Choose 'role' if there is one value, and 'roles' for an array of values. Change this in your config file at #{role_permissions_file_path})"
      end
    end

    # Transforms YAML hash formatting into correct format for require_role.
    # Also, enforces correct values for the 'options:' node.
    def reformat_options(hash)
      rehash = {}
      options = [['if', 'unless'], ['only', 'except', 'for', 'for_all_except']]
      hash.each_pair do |key, val|
        case
          when options[0].include?(key.to_s.downcase) then rehash[key.to_sym] = val.to_s
          when options[1].include?(key.to_s.downcase) then rehash[key.to_sym] =
               reformat_value(val)
          else
            raise "Unknown Option: #{key}, options are: #{options.flatten.inspect}"
        end
      end
      rehash
    end

    def reformat_value(value)
      value.is_a?(Array) ? value.map{|val| val.to_s} : value.to_s
    end
  end
end