# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module Hortidex
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dir)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def create_migration_file
        migration_template "install.rb", "db/migrate/hortidex_install.rb"
      end
    end
  end
end
