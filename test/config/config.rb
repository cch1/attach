# Read Application Configuration
# This script loads the application configuration from two YAML-formatted and
# ERB-processed files.  It has access to the Rails environment but little else.
# Both files support a section per Rails environment and the proper section is
# selected at initialization.
require 'ostruct'
require 'yaml'
require 'erb'
require 'pathname'

module AppConfig
  class << self
    def configuration
      @configuration || {}
    end

    # Peek into configuration of a specific environment
    def [](env)
      @environments[env.to_s].freeze
    end

    def load_configuration_files
      config_file = configuration_directory + "config.yml"
      raise "Can't read configuration file #{config_file}" unless config_file.readable?
      @environments = YAML.load(ERB.new(config_file.read).result)
      # The secrets file is intended to be protected from unauthorized access and may contain sensitive data.
      secrets_file = configuration_directory + "secrets.yml"
      @configuration = secrets_file.readable? ? YAML.load(ERB.new(secrets_file.read).result) : {}
    end

    def configuration_directory
      @configuration_directory ||= begin
        rr = defined?(RAILS_ROOT) ? Pathname.new(RAILS_ROOT) : Pathname.pwd
        rr.join('config')
      end
    end

    # Winnow the configuration down to a given environment, recursively merge with existing configuration and freeze configuration.
    def configure!(env = RAILS_ENV)
      raise "Can't determine Rails environment.  Do you need to set RAILS_ENV?" unless env
      merger = proc {|k,a,b| (Hash === a && Hash === b) ? a.merge(b, &merger) : b }
      configuration.merge!(@environments[env], &merger).freeze
    end

    def method_missing(sym)
      if configuration.has_key?(sym.to_s)
        configuration[sym.to_s] # Result is not frozen for BC reasons
      else
        super
      end
    end

    def respond_to?(sym)
      return configuration.has_key?(sym.to_s) || super
    end

    def to_s
      configuration.inspect
    end
  end
end

AppConfig.load_configuration_files