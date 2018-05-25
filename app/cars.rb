require_relative 'environment'

# get the years for all models
# - it gets the model years one at a time and takes about 12 minutes to run
def get_model_years_slow
  start = Time.now

  # open the json file of all cars and models
  json = JSON.parse(File.read(@all_cars_file))

  if json.nil?
    puts "ERROR - could not find json file"
    exit
  end

  # get all of the car ids with model ids
  # model_ids = json.map{|key, value| value['models'].keys}.flatten
  car_model_ids = json.map{|key, value| [key, value['models'].keys]}

  if car_model_ids.nil? || car_model_ids.length == 0
    puts "ERROR - could not find model ids"
    exit
  end

  puts "- found #{car_model_ids.length} cars with a total of #{car_model_ids.map{|x| x[1]}.flatten.length} models"

  total_left_to_process = car_model_ids.length
  car_model_ids.each_with_index do |car, index|
    puts "-------------------"
    puts "#{index} cars download so far in #{((Time.now-start)/60).round(2)} minutes\n\n"

    car[1].each do |model_id|
      puts "- car #{car[0]}, model #{model_id}"
      # save years
      json[car[0]]['models'][model_id]['years'] = JSON.parse(open("#{@model_years_url}#{model_id}").read)
    end
  end

  puts "FINISHED DOWNLOAD DATA!!"

  # save to file
  File.open(@all_cars_file_with_years, 'wb') { |file| file.write(JSON.generate(json)) }

  puts "TOTAL TIME TO DOWNLOAD AND WRITE TO FILE = #{((Time.now-start)/60).round(2)} minutes"
end




