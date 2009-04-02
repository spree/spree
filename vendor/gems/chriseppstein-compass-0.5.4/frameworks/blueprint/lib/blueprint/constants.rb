require 'fileutils'
module Blueprint
  module Constants
    # path to the root Blueprint directory
    ROOT_PATH =             File.expand_path(File.join(File.dirname(__FILE__), "../../"))
    # path to where the Blueprint CSS files are stored
    BLUEPRINT_ROOT_PATH =   File.join(ROOT_PATH, 'blueprint')
    # path to where the Blueprint CSS raw Sass files are stored
    SOURCE_PATH =           File.join(ROOT_PATH, 'src')
    # path to where the Blueprint CSS generated test files are stored
    EXAMPLES_PATH =         File.join(ROOT_PATH, 'examples')
    # path to the root of the Blueprint scripts
    LIB_PATH =              File.join(ROOT_PATH, 'lib', 'blueprint')
    # path to validator jar file to validate generated CSS files
    VALIDATOR_FILE =        File.join(LIB_PATH, 'validate', 'css-validator.jar')
  end
end
