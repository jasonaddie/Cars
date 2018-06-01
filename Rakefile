require_relative 'app/cars'

namespace :scraper do

  desc 'Get the years on file for each car model'
  task :get_model_years do
    get_model_years_fast
  end

  desc 'Get the overview info for each car model and year'
  task :get_overview do
    get_overview_info
  end

end

namespace :scraper_test do

  desc 'Get the overview info for a particular car and model'
  task :get_overview_info_for_model, [:car_id, :model_id] do |_t, args|
    puts args
    get_overview_info_for_model(args[:car_id], args[:model_id])
  end

end
