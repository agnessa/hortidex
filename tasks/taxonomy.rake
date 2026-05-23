# frozen_string_literal: true

namespace :taxonomy do
  desc "Apply the current Hortidex gem data to the database"
  task apply: :environment do
    Hortidex::ApplyTask.new.run
  end
end
