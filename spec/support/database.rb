# frozen_string_literal: true

require "active_record"
require "pg"

options = {adapter: "postgresql", database: "hortidex_test", min_messages: "warning"}
if ENV["CI"]
  options[:host] = "localhost"
  options[:username] = "postgres"
  options[:password] = "postgres"
end
ActiveRecord::Base.establish_connection(options)
ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS ltree")
