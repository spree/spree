Given /^no users exist with the role: "([^\"]*)"$/ do |role|
  Role.find_by_name(role).users.clear

  # hack to reset instance variables on rack metal
  %w(@admin_defined @status).each { |ivar|
    CreateAdminUser.instance_variable_set(ivar.to_sym, nil)
  }
end
