# frozen_string_literal: true

require_relative "lib/hortidex/version"

Gem::Specification.new do |spec|
  spec.name = "hortidex"
  spec.version = Hortidex::VERSION
  spec.authors = ["Agnieszka Figiel"]
  spec.license = "MIT"

  spec.summary = "Curated plant taxonomy dataset — POWO, UPOV, and EU PVP variety data"
  spec.description = <<~DESC
    Hortidex delivers a curated, versioned snapshot of plant taxonomy data derived from
    Plants of the World Online (WCVP), UPOV GENIE, and the EU Plant Variety Database.
    It ships as a Ruby gem containing CSV data files and an ActiveRecord-compatible apply
    task that upserts the dataset into a Postgres database.
  DESC

  git_tracked = Dir.chdir(__dir__) { `git ls-files -z 2>/dev/null`.split("\x0") }
  source_files = git_tracked.reject { |f| f.start_with?("spec/") || %w[Gemfile Gemfile.lock].include?(f) }
  data_files = Dir[File.join(__dir__, "data/*.{csv.gz,yml}")].map { |f| f.delete_prefix("#{__dir__}/") }
  spec.files = source_files + data_files
  spec.require_paths = ["lib"]

  spec.metadata = {
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/agnessa/hortidex",
    "changelog_uri" => "https://github.com/agnessa/hortidex/blob/main/CHANGELOG.md"
  }

  spec.required_ruby_version = ">= 3.3"

  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "csv"

  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "pg"
  spec.add_development_dependency "with_model"
  spec.add_development_dependency "standard"
  spec.add_development_dependency "bundler-audit"
  spec.add_development_dependency "simplecov"
end
