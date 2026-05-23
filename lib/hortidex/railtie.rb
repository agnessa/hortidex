# frozen_string_literal: true

require "rails/railtie"

module Hortidex
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("../../tasks/taxonomy.rake", __dir__)
    end
  end
end
