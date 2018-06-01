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

# get the years for all models
# - it gets the model years one at a time and takes about 12 minutes to run
def get_model_years_fast
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

  hydra = Typhoeus::Hydra.new(max_concurrency: 20)
  request = nil
  total_left_to_process = car_model_ids.length

  car_model_ids.each_with_index do |car, index|
    puts "-------------------"
    puts "#{index} cars download so far in #{((Time.now-start)/60).round(2)} minutes\n\n"

    car[1].each do |model_id|
      puts "- car #{car[0]}, model #{model_id}"
      request = Typhoeus::Request.new("#{@model_years_url}#{model_id}",
          :headers=>{"User-Agent" => @user_agent}, followlocation: true, ssl_verifypeer: false, ssl_verifyhost: 0)

      request.on_complete do |response|
        # save years
        json[car[0]]['models'][model_id]['years'] = JSON.parse(response.response_body)

        # decrease counter of items to process
        total_left_to_process -= 1
        if total_left_to_process == 0
          puts "TOTAL TIME TO DOWNLOAD = #{((Time.now-start)/60).round(2)} minutes"

        elsif total_left_to_process % 10 == 0
          puts "\n\n- #{total_left_to_process} files remain to download; time so far = #{((Time.now-start)/60).round(2)} minutes\n\n"
        end
      end
      hydra.queue(request)
    end
  end

  hydra.run


  puts "FINISHED DOWNLOAD DATA!!"

  # save to file
  File.open(@all_cars_file_with_years, 'wb') { |file| file.write(JSON.generate(json)) }

  puts "TOTAL TIME TO DOWNLOAD AND WRITE TO FILE = #{((Time.now-start)/60).round(2)} minutes"
end


# for each car, model, year
# call overview page to get
# - user reviews
# - expert rating (overall and broken down)
# - expert likes
# - expert dislikes
# - used price range
def get_overview_info
  start = Time.now

  # open the json file of all cars and models and years
  json = JSON.parse(File.read(@all_cars_file_with_years))

  if json.nil?
    puts "ERROR - could not find json file"
    exit
  end

  hydra = Typhoeus::Hydra.new(max_concurrency: 20)
  request = nil
  total_processed = 0
  total_cars_left_to_process = json.keys.length

  # for each car, model, year - get overview
  json.each do |key_car, car|
    puts "- car: #{car['name']}"
    car['models'].each do |key_model, model|
      puts "- model: #{model['name']}"

      model['overview'] = Hash.new

      model['years'].each do |year|
        # request the url
        request = Typhoeus::Request.new(
          @overiew_url.gsub('{car}', car['seo']).gsub('{model}', model['seo']).gsub('{year}', year.to_s),
          :headers=>{"User-Agent" => @user_agent},
          followlocation: true, ssl_verifypeer: false, ssl_verifyhost: 0)

        request.on_complete do |response|
          # process the html
          model['overview'][year] = process_overview_page(response.response_body)

          total_processed += 1

          if total_processed % 100 == 0
            puts "\n\n- #{total_processed} overview files downloaded; time so far = #{((Time.now-start)/60).round(2)} minutes\n\n"
          end
        end
        hydra.queue(request)
      end
    end
    # decrease counter of items to process
    total_cars_left_to_process -= 1
    puts "\n------------\n- #{total_cars_left_to_process} cars left to process; time so far = #{((Time.now-start)/60).round(2)} minutes\n\n"

  end

  hydra.run

  puts "FINISHED DOWNLOAD DATA!!"

  # save to file
  File.open(@all_cars_file_with_years_overview, 'wb') { |file| file.write(JSON.generate(json)) }

  puts "TOTAL TIME TO DOWNLOAD AND WRITE OVERVIEWS TO FILE = #{((Time.now-start)/60).round(2)} minutes"
end

# pull out the content from the overview page
# - user reviews
# - expert rating (overall and broken down)
# - expert likes
# - expert dislikes
# - used price range
def process_overview_page(response_body)
  hash = {}

  if !response_body.nil?
    doc = Nokogiri.HTML(response_body)

    # user reviews - rating
    hash['used_reviews_rating'] = nil
    x = doc.css('.user-reviews .star-actual').first
    hash['used_reviews_rating'] = (x['data-width'].to_i / 26) if !x.nil?

    # user reviews - number
    hash['used_reviews_number'] = nil
    x = doc.css('.user-reviews .total-review').first
    hash['used_reviews_number'] = x.text.to_i if !x.nil?

    # expert rating
    hash['expert_rating'] = Hash.new
    if !doc.css('.expert-ratings-block').nil?
      # - overall
      hash['expert_rating']['overview'] = nil
      x = doc.css('.expert-ratings-block .ratingNumber').first
      hash['expert_rating']['overview'] = x.text.to_f if !x.nil?

      doc.css('.expert-ratings-block table > tr').each do |row|
        key = @expert_ratings[row.css('td:eq(1)').text]
        if !key.nil?
          hash['expert_rating'][key] = nil
          rating = row.css('td:eq(2)').text
          hash['expert_rating'][key] = rating.to_i if !rating.nil?
        end
      end
    end

    # expert likes
    hash['expert_likes'] = []
    doc.css('#likes ul li').each do |item|
      hash['expert_likes'] << item.text
    end

    # expert dislikes
    hash['expert_dislikes'] = []
    doc.css('#dislikes ul li').each do |item|
      hash['expert_dislikes'] << item.text
    end

    # user price range
    hash['used_price_range'] = nil
    x = doc.css('.used-yrmd-price a').first
    hash['used_price_range'] = x.text if !x.nil?

  end

  return hash
end

#####################
## TESTING
#####################

# this method is just for testing the overview process
# - it is a simplification of get_overview_info
# - must supply car and model id to get overview for
def get_overview_info_for_model(car_id, model_id)
  if car_id.nil? || model_id.nil?
    puts "ERROR - car_id and model_id are required"
    exit
  end

  start = Time.now

  # open the json file of all cars and models and years
  json = JSON.parse(File.read(@all_cars_file_with_years))

  if json.nil?
    puts "ERROR - could not find json file"
    exit
  end

  # find the car / model
  car = json[car_id]
  model = car['models'][model_id] if !car.nil?
  if car.nil? || model.nil?
    puts "ERROR - could not find car or model"
    exit
  end

  model['overview'] = Hash.new

  model['years'].each do |year|
    puts "- #{year}"
    response = Typhoeus.get(
      @overiew_url.gsub('{car}', car['seo']).gsub('{model}', model['seo']).gsub('{year}', year.to_s),
      :headers=>{"User-Agent" => @user_agent},
      followlocation: true, ssl_verifypeer: false, ssl_verifyhost: 0)

    model['overview'][year] = process_overview_page(response.response_body)
  end

  puts model['overview']

  puts "TOTAL TIME TO DOWNLOAD OVERVIEW AND PARSE = #{((Time.now-start)/60).round(2)} minutes"

end
