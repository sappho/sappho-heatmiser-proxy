require 'singleton'
require 'yaml'

class SystemConfiguration

  include Singleton

  attr_reader :config

  def initialize
    @config = YAML.load_file 'config.yml'
  end

end