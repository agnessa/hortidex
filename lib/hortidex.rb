# frozen_string_literal: true

require "active_support/concern"
require "hortidex/version"
require "hortidex/constants"
require "hortidex/name_formatter"
require "hortidex/taxon_concept"
require "hortidex/apply_task"
require "hortidex/railtie" if defined?(Rails)

module Hortidex
  class Configuration
    attr_accessor :taxon_reference_columns
    attr_accessor :locales  # nil means all available; set to e.g. %w[en fr de] to restrict

    def initialize
      @taxon_reference_columns = []
      @locales = nil
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end
  end
end
