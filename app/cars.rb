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
# - it gets the model years in parallel and takes about 3 minutes to run
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

  hydra = Typhoeus::Hydra.new(max_concurrency: @max_concurrency)
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
# json format
# car -> model -> details -> year -> overview
# takes about 17 minutes to run
def get_overview_info
  start = Time.now

  # open the json file of all cars and models and years
  json = JSON.parse(File.read(@all_cars_file_with_years))

  if json.nil?
    puts "ERROR - could not find json file"
    exit
  end

  hydra = Typhoeus::Hydra.new(max_concurrency: @max_concurrency)
  request = nil
  total_to_download = json.values.map{|x| x['models'].values.map{|y| y['years'].length}}.flatten.inject(0, :+)
  total_left_to_download = json.values.map{|x| x['models'].values.map{|y| y['years'].length}}.flatten.inject(0, :+)

  # for each car, model, year - get overview
  json.each do |key_car, car|
    car['models'].each do |key_model, model|

      model['details'] = Hash.new

      model['years'].each do |year|
        model['details'][year] = Hash.new

        # request the url
        request = Typhoeus::Request.new(
          @overiew_url.gsub('{car}', car['seo']).gsub('{model}', model['seo']).gsub('{year}', year.to_s),
          :headers=>{"User-Agent" => @user_agent},
          followlocation: true, ssl_verifypeer: false, ssl_verifyhost: 0
        )

        request.on_complete do |response|
          # process the html
          model['details'][year]['overview'] = process_overview_page(response.response_body)

          total_left_to_download -= 1

          if total_left_to_download % 100 == 0
            puts "\n\n- #{total_left_to_download} overview files left to downloaded (out of #{total_to_download}); time so far = #{((Time.now-start)/60).round(2)} minutes\n\n"
          end
        end
        hydra.queue(request)
      end
    end
  end

  hydra.run

  puts "FINISHED DOWNLOAD DATA!!"

  # save to file
  File.open(@all_cars_file_with_years_overview, 'wb') { |file| file.write(JSON.generate(json)) }

  puts "TOTAL TIME TO DOWNLOAD AND WRITE OVERVIEWS TO FILE = #{((Time.now-start)/60).round(2)} minutes"
end


# for each, car, model, year
# call the default specs page and get the styles
# and since the page is already downloaded,
# go ahead and process the spec data for the default style
def get_styles_info
  start = Time.now

  # open the json file of all cars and models and years
  json = JSON.parse(File.read(@all_cars_file_with_years_overview))

  if json.nil?
    puts "ERROR - could not find json file"
    exit
  end

  hydra = Typhoeus::Hydra.new(max_concurrency: @max_concurrency)
  request = nil
  total_to_download = json.values.map{|x| x['models'].values.map{|y| y['years'].length}}.flatten.inject(0, :+)
  total_left_to_download = json.values.map{|x| x['models'].values.map{|y| y['years'].length}}.flatten.inject(0, :+)

  # for each car, model, year - get overview
  json.each do |key_car, car|
    puts "-----------"
    puts "car: #{car['name']}"
    car['models'].each do |key_model, model|
      puts "- model: #{model['name']}"
      model['years'].each do |year|
        year = year.to_s

        # only continue if the specs url exists
        if !model['details'][year]['overview']['specs_url_slug'].nil?

          model['details'][year]['styles'] = Hash.new

          # call the default style page and get all of the styles
          request = Typhoeus::Request.new(
            @specs_url.gsub('{slug}', model['details'][year]['overview']['specs_url_slug']),
            :headers=>{"User-Agent" => @user_agent},
            followlocation: true, ssl_verifypeer: false, ssl_verifyhost: 0
          )

          request.on_complete do |response|
            # get list of each style
            styles = process_specification_for_styles(response.response_body)

            if !styles.nil? && styles.length > 0
              styles.each do |style|
                model['details'][year]['styles'][style] = nil

                # if the style is the same as the overview specs url slug
                # then we have already retrieved the page and we can just process it.
                if style == model['details'][year]['overview']['specs_url_slug']
                  # process the html
                  model['details'][year]['styles'][style] = process_specification_page(response.response_body)
                end
              end
            end

            total_left_to_download -= 1

            if total_left_to_download % 50 == 0
              puts "\n\n- #{total_left_to_download} style specification files downloaded (out of at #{total_to_download}); time so far = #{((Time.now-start)/60).round(2)} minutes\n\n"
            end

          end

          hydra.queue(request)
        end
      end
    end
  end

  hydra.run

  puts "FINISHED DOWNLOAD DATA!!"

  # save to file
  File.open(@all_cars_file_with_years_overview_styles, 'wb') { |file| file.write(JSON.generate(json)) }

  puts "TOTAL TIME TO DOWNLOAD AND WRITE STYLE SPECIFICATIONS TO FILE = #{((Time.now-start)/60).round(2)} minutes"
end

# for each car, model, year, style
# call specifications page to get
# - links to all styles of model
# - msrp
# - dimensions
# - fuel economy
# - performance
# - safety features
# - waranty
# - other specs
# takes about ___ minutes to run
def get_specification_info
  start = Time.now

  # open the json file of all cars and models and years
  # if the specs file exists, use it, else start with the styles
  json = if File.exist?(@all_cars_file_with_years_overview_styles_specs)
    JSON.parse(File.read(@all_cars_file_with_years_overview_styles_specs))
  else
    JSON.parse(File.read(@all_cars_file_with_years_overview_styles))
  end

  if json.nil?
    puts "ERROR - could not find json file"
    exit
  end

  hydra = Typhoeus::Hydra.new(max_concurrency: @max_concurrency)
  request = nil
  total_downloaded = 0
  total_to_download = 0

  # for each car, model, year - get overview
  json.each do |key_car, car|
    puts "-----------"
    puts "car: #{car['name']}"
    car['models'].each do |key_model, model|
      puts "- model: #{model['name']}"
      model['years'].each do |year|
        year = year.to_s

        # only continue if the styles hash exists
        if !model['details'][year]['styles'].nil?

          model['details'][year]['styles'].keys.each do |style|
            # if the style data already exists, skip it
            # else get the data
            if model['details'][year]['styles'][style].nil?

              request = Typhoeus::Request.new(
                @specs_url.gsub('{slug}', style),
                :headers=>{"User-Agent" => @user_agent},
                followlocation: true, ssl_verifypeer: false, ssl_verifyhost: 0
              )

              total_to_download += 1

              request.on_complete do |response|
                # process the html
                model['details'][year]['styles'][style] = process_specification_page(response.response_body)

                total_downloaded += 1

                if total_downloaded % 50 == 0
                  puts "\n\n- #{total_downloaded} specification files downloaded so far (out of #{total_to_download}); time so far = #{((Time.now-start)/60).round(2)} minutes\n\n"
                end

                # since there are lots of files to download
                # let's save to file after every 1000 records are processed
                if total_downloaded % 1000 == 0
                  puts "\n\n- saving to file \n\n"
                  File.open(@all_cars_file_with_years_overview_styles_specs, 'wb') { |file| file.write(JSON.generate(json)) }
                end
              end
              hydra.queue(request)
            end
          end
        end
      end
    end
  end

  hydra.run

  puts "FINISHED DOWNLOAD DATA!!"

  # save to file
  File.open(@all_cars_file_with_years_overview_styles_specs, 'wb') { |file| file.write(JSON.generate(json)) }

  puts "TOTAL TIME TO DOWNLOAD AND WRITE SPECIFICATIONS TO FILE = #{((Time.now-start)/60).round(2)} minutes"
end


#####################
## CSS PROCESSING OF PAGE
#####################

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

    # default specs page url
    hash['specs_url_slug'] = nil
    x = doc.css('#ymm-nav-specs-btn').first
    hash['specs_url_slug'] = x['href'].split('/').last if !x.nil?

    # ranking - number
    hash['expert_ranking_number'] = nil
    x = doc.css('.primary-rank span').first
    hash['expert_ranking_number'] = x.text.gsub('#', '').to_i if !x.nil?

    # ranking - category
    hash['expert_ranking_category'] = nil
    x = doc.css('.primary-rank a').first
    hash['expert_ranking_category'] = x.text if !x.nil?

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
          hash['expert_rating'][key] = rating.to_i if !rating.nil? && rating != '' && rating.downcase != 'n/a'
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

# the specs page has a list of styles
# - get the styles and return in format of [style_slug]
def process_specification_for_styles(response_body)
  styles = []

  if !response_body.nil?
    doc = Nokogiri.HTML(response_body)

    doc.css('#trims-select-popup ul li').each do |li|
      # get slug
      styles << (li['data-url'].split('/').last)
    end
  end
  return styles
end

# pull out the content from the specification page
# - msrp
# - dimensions
# - fuel economy
# - performance
# - safety features
# - waranty
# - other specs
def process_specification_page(response_body, short_dataset_only=true)
  hash = {}

  if !response_body.nil?
    doc = Nokogiri.HTML(response_body)

    # msrp
    hash['msrp'] = nil
    x = doc.css('#style-price a').first
    hash['msrp'] = x.text.gsub('$', '').gsub(',', '').to_i if !x.nil? && x.text.length > 0

    get_specifications_value(doc, hash, 'style', 'Style Name')
    get_specifications_value(doc, hash, 'body_style', 'Body Style')
    get_specifications_value(doc, hash, 'passenger_doors', 'Passenger Doors', integer: true)
    get_specifications_value(doc, hash, 'transmission', 'Transmission')

    # DIMENSIONS
    get_specifications_value(doc, hash, 'epa_classification', 'EPA Classification')
    get_specifications_value(doc, hash, 'passenger_capacity', 'Passenger Capacity', integer: true)
    get_specifications_value(doc, hash, 'front_head_room', 'Front Head Room (in)', float: true)
    get_specifications_value(doc, hash, 'front_shoulder_room', 'Front Shoulder Room (in)', float: true)
    get_specifications_value(doc, hash, 'front_hip_room', 'Front Hip Room (in)', float: true)
    get_specifications_value(doc, hash, 'front_leg_room', 'Front Leg Room (in)', float: true)
    get_specifications_value(doc, hash, 'second_head_room', 'Second Head Room (in)', float: true)
    get_specifications_value(doc, hash, 'second_shoulder_room', 'Second Shoulder Room (in)', float: true)
    get_specifications_value(doc, hash, 'second_hip_room', 'Second Hip Room (in)', float: true)
    get_specifications_value(doc, hash, 'second_leg_room', 'Second Leg Room (in)', float: true)
    get_specifications_value(doc, hash, 'third_head_room', 'Third Head Room (in)', float: true)
    get_specifications_value(doc, hash, 'third_shoulder_room', 'Third Shoulder Room (in)', float: true)
    get_specifications_value(doc, hash, 'third_hip_room', 'Third Hip Room (in)', float: true)
    get_specifications_value(doc, hash, 'third_leg_room', 'Third Leg Room (in)', float: true)

    get_specifications_value(doc, hash, 'width', 'Width, Max w/o mirrors (in)', float: true)
    get_specifications_value(doc, hash, 'height', 'Height, Overall (in)', float: true)
    get_specifications_value(doc, hash, 'length', 'Length, Overall (in)', float: true)
    get_specifications_value(doc, hash, 'ground_clearance', 'Min Ground Clearance (in)', float: true)

    get_specifications_value(doc, hash, 'trunk_volume', 'Trunk Volume (ft³)', float: true)
    get_specifications_value(doc, hash, 'cargo_area_width', 'Cargo Box Width @ Wheelhousings (in)', float: true)
    get_specifications_value(doc, hash, 'cargo_area_height', 'Cargo Box (Area) Height (in)', float: true)
    get_specifications_value(doc, hash, 'cargo_area_length_floor_to_seat2', 'Cargo Area Length @ Floor to Seat 2 (in)', float: true)
    get_specifications_value(doc, hash, 'cargo_area_volume_to_seat1', 'Cargo Volume to Seat 1 (ft³)', float: true)
    get_specifications_value(doc, hash, 'cargo_area_volume_to_seat2', 'Cargo Volume to Seat 2 (ft³)', float: true)
    get_specifications_value(doc, hash, 'cargo_are_volume_to_seat3', 'Cargo Volume to Seat 3 (ft³)', float: true)


    # FUEL ECONOMY
    get_specifications_value(doc, hash, 'fuel_tank_capacity', 'Fuel Tank Capacity, Approx (gal)', integer: true)
    get_specifications_value(doc, hash, 'mpg_city', 'EPA Fuel Economy Est - City (MPG)', integer: true)
    get_specifications_value(doc, hash, 'mpg_highway', 'EPA Fuel Economy Est - Hwy (MPG)', integer: true)
    get_specifications_value(doc, hash, 'mpg_combined', 'Fuel Economy Est-Combined (MPG)', integer: true)
    get_specifications_value(doc, hash, 'battery_range', 'Battery Range (mi)')
    get_specifications_value(doc, hash, 'mpg_equivalent_city', 'EPA MPG Equivalent - City')
    get_specifications_value(doc, hash, 'mpg_equivalent_hwy', 'EPA MPG Equivalent - Hwy')
    get_specifications_value(doc, hash, 'mpg_equivalent_combined', 'EPA MPG Equivalent - Combined')


    # PERFORMANCE SPECS
    get_specifications_value(doc, hash, 'engine_type', 'Engine Type')
    get_specifications_value(doc, hash, 'engine_displacement', 'Displacement')
    get_specifications_value(doc, hash, 'horsepower', 'SAE Net Horsepower @ RPM')
    get_specifications_value(doc, hash, 'fuel_system', 'Fuel System')

    get_specifications_value(doc, hash, 'brakes_abs', 'Brake ABS System')
    get_specifications_value(doc, hash, 'brakes_disc_front', 'Disc - Front (Yes or   )')
    get_specifications_value(doc, hash, 'brakes_disc_rear', 'Disc - Rear (Yes or   )')
    get_specifications_value(doc, hash, 'brakes_drum_rear', 'Drum - Rear (Yes or   )')

    get_specifications_value(doc, hash, 'steering_type', 'Steering Type')
    get_specifications_value(doc, hash, 'turning_diameter', 'Turning Diameter - Curb to Curb (ft)', float: true)


    # SAFETY FEATURES
    get_specifications_value(doc, hash, 'air_bag_front_driver', 'Air Bag-Frontal-Driver')
    get_specifications_value(doc, hash, 'air_bag_front_passenger', 'Air Bag-Frontal-Passenger')
    get_specifications_value(doc, hash, 'air_bag_front_passenger_switch', 'Air Bag-Passenger Switch (On/Off)')
    get_specifications_value(doc, hash, 'air_bag_side_head_front', 'Air Bag-Side Head-Front')
    get_specifications_value(doc, hash, 'air_bag_side_body_front', 'Air Bag-Side Body-Front')
    get_specifications_value(doc, hash, 'air_bag_side_head_rear', 'Air Bag-Side Head-Rear')
    get_specifications_value(doc, hash, 'air_bag_side_body_rear', 'Air Bag-Side Body-Rear')
    get_specifications_value(doc, hash, 'brakes_abs', 'Brakes-ABS')
    get_specifications_value(doc, hash, 'child_door_locks', 'Child Safety Rear Door Locks')
    get_specifications_value(doc, hash, 'other_features', 'Other Features')



    # if the entire dataset is desired, continue
    if !short_dataset_only

      # DIMENSIONS
      get_specifications_value(doc, hash, 'base_curb_weight', 'Base Curb Weight (lbs)', integer: true)
      get_specifications_value(doc, hash, 'passenger_volume', 'Passenger Volume (ft³)', float: true)
      get_specifications_value(doc, hash, '', 'Gross Combined Wt Rating (lbs)')
      get_specifications_value(doc, hash, '', 'Curb Weight - Front (lbs)')
      get_specifications_value(doc, hash, '', 'Curb Weight - Rear (lbs)')
      get_specifications_value(doc, hash, '', 'Gross Axle Wt Rating - Front (lbs)')
      get_specifications_value(doc, hash, '', 'Gross Axle Wt Rating - Rear (lbs)')
      get_specifications_value(doc, hash, '', 'Gross Vehicle Weight Rating Cap (lbs)')

      get_specifications_value(doc, hash, 'wheelbase', 'Wheelbase (in)', float: true)
      get_specifications_value(doc, hash, 'track_width_front', 'Track Width, Front (in)', float: true)
      get_specifications_value(doc, hash, 'track_width_rear', 'Track Width, Rear (in)', float: true)
      get_specifications_value(doc, hash, 'liftover_height', 'Liftover Height (in)', float: true)
      get_specifications_value(doc, hash, '', 'Ground Clearance, Front (in)')
      get_specifications_value(doc, hash, '', 'Overhang, Rear w/o bumper (in)')
      get_specifications_value(doc, hash, '', 'Ground to Top of Frame (in)')
      get_specifications_value(doc, hash, '', 'Cab to End of Frame (in)')
      get_specifications_value(doc, hash, '', 'Ground Clearance, Rear (in)')
      get_specifications_value(doc, hash, '', 'Length, Overall w/o rear bumper (in)')
      get_specifications_value(doc, hash, '', 'Front Bumper to Back of Cab (in)')
      get_specifications_value(doc, hash, '', 'Frame Width, Rear (in)')
      get_specifications_value(doc, hash, '', 'Overhang, Front (in)')
      get_specifications_value(doc, hash, '', 'Ground to Top of Load Floor (in)')
      get_specifications_value(doc, hash, '', 'Cab to Axle (in)')
      get_specifications_value(doc, hash, '', 'Rear Door Type')
      get_specifications_value(doc, hash, '', 'Rear Door Opening Height (in)')
      get_specifications_value(doc, hash, '', 'Step Up Height - Side (in)')
      get_specifications_value(doc, hash, '', 'Side Door Opening Width (in)')
      get_specifications_value(doc, hash, '', 'Overhang, Rear w/bumper (in)')
      get_specifications_value(doc, hash, '', 'Rear Door Opening Width (in)')
      get_specifications_value(doc, hash, '', 'Step Up Height - Front (in)')
      get_specifications_value(doc, hash, '', 'Length, Overall w/rear bumper (in)')
      get_specifications_value(doc, hash, '', 'Side Door Opening Height (in)')


      get_specifications_value(doc, hash, '', 'Cargo Box Length @ Floor (in)')
      get_specifications_value(doc, hash, '', 'Cargo Box Width @ Floor (in)')
      get_specifications_value(doc, hash, '', 'Cargo Box Width @ Top, Rear (in)')
      get_specifications_value(doc, hash, '', 'Cargo Volume (ft³)')
      get_specifications_value(doc, hash, '', 'Ext\'d Cab Cargo Volume (ft³)')
      get_specifications_value(doc, hash, '', 'Cargo Area Width @ Beltline (in)')
      get_specifications_value(doc, hash, '', 'Cargo Area Length @ Floor to Seat 1 (in)')
      get_specifications_value(doc, hash, '', 'Tailgate Width (in)')
      get_specifications_value(doc, hash, '', 'Cargo Area Length @ Floor to Seat 4 (in)')
      get_specifications_value(doc, hash, '', 'Cargo Area Length @ Floor to Console (in)')
      get_specifications_value(doc, hash, '', 'Cargo Area Length @ Floor to Seat 3 (in)')
      get_specifications_value(doc, hash, '', 'Cargo Volume to Seat 4 (ft³)')
      get_specifications_value(doc, hash, '', 'Cargo Volume with Rear Seat Up (ft³)')
      get_specifications_value(doc, hash, '', 'Cargo Volume with Rear Seat Down (ft³)')

      # PERFORMANCE SPECS
      get_specifications_value(doc, hash, 'torque', 'SAE Net Torque @ RPM')
      get_specifications_value(doc, hash, 'engine_order_code', 'Engine Order Code')

      get_specifications_value(doc, hash, '', 'Aux Fuel Tank Location')
      get_specifications_value(doc, hash, '', 'Aux Fuel Tank Capacity, Approx (gal)')
      get_specifications_value(doc, hash, '', 'Fuel Tank Location')

      get_specifications_value(doc, hash, '', 'Engine Oil Cooler')

      get_specifications_value(doc, hash, 'drivetrain', 'Drivetrain')
      get_specifications_value(doc, hash, 'first_gear_ratio', 'First Gear Ratio (:1)')
      get_specifications_value(doc, hash, '', 'Second Gear Ratio (:1)')
      get_specifications_value(doc, hash, '', 'Third Gear Ratio (:1)')
      get_specifications_value(doc, hash, '', 'Fourth Gear Ratio (:1)')
      get_specifications_value(doc, hash, '', 'Fifth Gear Ratio (:1)')
      get_specifications_value(doc, hash, '', 'Sixth Gear Ratio (:1)')
      get_specifications_value(doc, hash, '', 'Seventh Gear Ratio (:1)')
      get_specifications_value(doc, hash, '', 'Eighth Gear Ratio (:1)')
      get_specifications_value(doc, hash, '', 'Clutch Size (in)')
      get_specifications_value(doc, hash, '', 'Transfer Case Gear Ratio (:1), Low')
      get_specifications_value(doc, hash, '', 'Transfer Case Model')
      get_specifications_value(doc, hash, '', 'Trans Power Take Off')
      get_specifications_value(doc, hash, '', 'Transfer Case Power Take Off')
      get_specifications_value(doc, hash, '', 'Transfer Case Gear Ratio (:1), High')
      get_specifications_value(doc, hash, '', 'Trans PTO Access')

      get_specifications_value(doc, hash, '', 'Axle Type - Front')
      get_specifications_value(doc, hash, '', 'Axle Capacity - Front (lbs)')
      get_specifications_value(doc, hash, '', 'Axle Ratio (:1) - Front')
      get_specifications_value(doc, hash, '', 'Axle Type - Rear')
      get_specifications_value(doc, hash, '', 'Axle Ratio (:1) - Rear')
      get_specifications_value(doc, hash, '', 'Axle Capacity - Rear (lbs)')
      get_specifications_value(doc, hash, '', 'Spring Capacity - Front (lbs)')
      get_specifications_value(doc, hash, '', 'Shock Absorber Diameter - Front (mm)')
      get_specifications_value(doc, hash, '', 'Stabilizer Bar Diameter - Front (in)')
      get_specifications_value(doc, hash, '', 'Spring Capacity - Rear (lbs)')
      get_specifications_value(doc, hash, '', 'Shock Absorber Diameter - Rear (mm)')
      get_specifications_value(doc, hash, '', 'Stabilizer Bar Diameter - Rear (in)')

      get_specifications_value(doc, hash, 'reverse_ratio', 'Reverse Ratio (:1)', float: true)
      get_specifications_value(doc, hash, 'final_drive_axle_ratio', 'Final Drive Axle Ratio (:1)', float: true)
      get_specifications_value(doc, hash, 'trans_type', 'Trans Type')
      get_specifications_value(doc, hash, 'trans_desc_cont', 'Trans Description Cont.')
      get_specifications_value(doc, hash, 'trans_desc_cont2', 'Trans Description Cont. Again')
      get_specifications_value(doc, hash, 'trans_order_code', 'Trans Order Code')

      get_specifications_value(doc, hash, 'brakes_front_drum_thickness', 'Front Brake Rotor Diam x Thickness (in)', float: true)
      get_specifications_value(doc, hash, 'brakes_rear_drum_thickness', 'Rear Brake Rotor Diam x Thickness (in)', float: true)
      get_specifications_value(doc, hash, 'brakes_rear_drum_width', 'Rear Drum Diam x Width (in)', float: true)
      get_specifications_value(doc, hash, '', 'Brake Type')
      get_specifications_value(doc, hash, '', 'Brake ABS System (Second Line)')

      get_specifications_value(doc, hash, '', 'Steering Ratio (:1), On Center')
      get_specifications_value(doc, hash, '', 'Turning Diameter - Wall to Wall (ft)')
      get_specifications_value(doc, hash, '', 'Steering Ratio (:1), At Lock')

      get_specifications_value(doc, hash, '', 'Revolutions/Mile @ 45 mph - Rear')
      get_specifications_value(doc, hash, '', 'Spare Tire Capacity (lbs)')
      get_specifications_value(doc, hash, '', 'Front Tire Capacity (lbs)')
      get_specifications_value(doc, hash, '', 'Revolutions/Mile @ 45 mph - Spare')
      get_specifications_value(doc, hash, '', 'Revolutions/Mile @ 45 mph - Front')
      get_specifications_value(doc, hash, '', 'Rear Tire Capacity (lbs)')

      get_specifications_value(doc, hash, 'tire_front_size', 'Front Tire Size')
      get_specifications_value(doc, hash, 'tire_front_code', 'Front Tire Order Code')
      get_specifications_value(doc, hash, 'tire_rear_size', 'Rear Tire Size')
      get_specifications_value(doc, hash, 'tire_rear_code', 'Rear Tire Order Code')
      get_specifications_value(doc, hash, 'tire_spare_size', 'Spare Tire Size')
      get_specifications_value(doc, hash, 'tire_spare_code', 'Spare Tire Order Code')

      get_specifications_value(doc, hash, 'wheel_front_size', 'Front Wheel Size (in)')
      get_specifications_value(doc, hash, 'wheel_front_material', 'Front Wheel Material')
      get_specifications_value(doc, hash, 'wheel_rear_size', 'Rear Wheel Size (in)')
      get_specifications_value(doc, hash, 'wheel_rear_material', 'Rear Wheel Material')
      get_specifications_value(doc, hash, 'wheel_spare_size', 'Spare Wheel Size (in)')
      get_specifications_value(doc, hash, 'wheel_spare_material', 'Spare Wheel Material')

      get_specifications_value(doc, hash, 'suspension_type_front', 'Suspension Type - Front')
      get_specifications_value(doc, hash, 'suspension_type_front2', 'Suspension Type - Front (Cont.)')
      get_specifications_value(doc, hash, 'suspension_type_rear', 'Suspension Type - Rear')
      get_specifications_value(doc, hash, 'suspension_type_rear2', 'Suspension Type - Rear (Cont.)')


      # SAFETY FEATURES
      get_specifications_value(doc, hash, 'daytime_lights', 'Daytime Running Lights')
      get_specifications_value(doc, hash, 'fog_lamps', 'Fog Lamps')
      get_specifications_value(doc, hash, 'night_vision', 'Night Vision')
      get_specifications_value(doc, hash, 'backup_camera', 'Back-Up Camera')
      get_specifications_value(doc, hash, 'parking_aid', 'Parking Aid')
      get_specifications_value(doc, hash, 'traction_control', 'Traction Control')
      get_specifications_value(doc, hash, 'tire_pressure_monitor', 'Tire Pressure Monitor')
      get_specifications_value(doc, hash, 'stability_control', 'Stability Control')
      get_specifications_value(doc, hash, 'rollover_protection_bars', 'Rollover Protection Bars')


      # WARRANTY
      get_specifications_value(doc, hash, 'warranty_years', 'Basic Years', integer: true)
      get_specifications_value(doc, hash, 'warranty_miles', 'Basic Miles/km')
      get_specifications_value(doc, hash, 'warranty_drivetrain_year', 'Drivetrain Years', integer: true)
      get_specifications_value(doc, hash, 'warranty_drivetrain_mils', 'Drivetrain Miles/km')
      get_specifications_value(doc, hash, 'warranty_corrosion_years', 'Corrosion Years', integer: true)
      get_specifications_value(doc, hash, 'warranty_corrosion_miles', 'Corrosion Miles/km')
      get_specifications_value(doc, hash, 'warranty_roadside_years', 'Roadside Assistance Years', integer: true)
      get_specifications_value(doc, hash, 'warranty_roadside_miles', 'Roadside Assistance Miles/km')
      get_specifications_value(doc, hash, '', 'Hybrid/Electric Components Miles/km')
      get_specifications_value(doc, hash, '', 'Hybrid/Electric Components Years')
      get_specifications_value(doc, hash, '', 'Maintenance Miles/km')
      get_specifications_value(doc, hash, '', 'Maintenance Years')
      get_specifications_value(doc, hash, '', 'Drivetrain Note')
      get_specifications_value(doc, hash, '', 'Maintenance Note')
      get_specifications_value(doc, hash, '', 'Roadside Assistance Note')
      get_specifications_value(doc, hash, '', 'Emissions Miles/km')
      get_specifications_value(doc, hash, '', 'Emissions Years')



      # OTHER SPECS
      get_specifications_value(doc, hash, 'cold_cranking_amps', 'Cold Cranking Amps @ 0° F (Primary)', integer: true)
      get_specifications_value(doc, hash, '', 'Total Cooling System Capacity (qts)')
      get_specifications_value(doc, hash, '', 'Maximum Alternator Watts')
      get_specifications_value(doc, hash, '', 'Cold Cranking Amps @ 0° F (2nd)')
      get_specifications_value(doc, hash, 'max_alternator_capacity', 'Maximum Alternator Capacity (amps)', integer: true)
      get_specifications_value(doc, hash, 'max_trailering_capacity', 'Maximum Trailering Capacity (lbs)', integer: true)
      get_specifications_value(doc, hash, 'max_trailer_weight_distributing_hitch', 'Wt Distributing Hitch - Max Trailer Wt. (lbs)', integer: true)
      get_specifications_value(doc, hash, 'max_tongue_weight_distributing_hitch', 'Wt Distributing Hitch - Max Tongue Wt. (lbs)', integer: true)
      get_specifications_value(doc, hash, 'max_trailer_weight_dead_weight_hitch', 'Dead Weight Hitch - Max Trailer Wt. (lbs)', integer: true)
      get_specifications_value(doc, hash, 'max_tongue_weight_dead_weight_hitch', 'Dead Weight Hitch - Max Tongue Wt. (lbs)', integer: true)
      get_specifications_value(doc, hash, '', 'Fifth Wheel Hitch - Max Tongue Wt. (lbs)')
      get_specifications_value(doc, hash, '', 'Fifth Wheel Hitch - Max Trailer Wt. (lbs)')
      get_specifications_value(doc, hash, '', 'Wt Distributing Hitch - Max Trailer Wt. (lbs)')

    end

  end

  return hash
end

# the path for all spec values follow the same pattern
def get_specifications_value(doc, hash, hash_key, css_contains_text, options={})
  hash[hash_key] = nil
  x = doc.css('.specs-set-item .key:contains("{css_contains_text}") + .value'.gsub('{css_contains_text}', css_contains_text)).first
  if !x.nil? && x.text != 'NA' && x.text != '- TBD -'
    if options[:integer] == true
      hash[hash_key] = x.text.to_i
    elsif options[:float] == true
      hash[hash_key] = x.text.to_f
    else
      hash[hash_key] = x.text
    end
  end
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

  puts model['overview'].to_json

  puts "TOTAL TIME TO DOWNLOAD OVERVIEW AND PARSE = #{((Time.now-start)/60).round(2)} minutes"

end



# this method is just for testing the overview process
# - it is a simplification of get_specification_info
# - must supply car and model id to get specification for
def get_specification_info_for_model(car_id, model_id, year_limit=4)
  if car_id.nil? || model_id.nil?
    puts "ERROR - car_id and model_id are required"
    exit
  end

  start = Time.now

  # open the json file of all cars and models and years
  json = JSON.parse(File.read(@all_cars_file_with_years_overview))

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

  model['years'].each_with_index do |year, year_index|
    if year_index > year_limit
      break
    end

    year = year.to_s
    puts "- #{year}"

    model['details'][year]['styles'] = Hash.new

    # call the default style page and get all of the styles
    response_default_page = Typhoeus.get(
      @specs_url.gsub('{slug}', model['details'][year]['overview']['specs_url_slug']),
      :headers=>{"User-Agent" => @user_agent},
      followlocation: true, ssl_verifypeer: false, ssl_verifyhost: 0
    )
    # request each style
    styles = process_specification_for_styles(response_default_page.response_body)

    if !styles.nil? && styles.length > 0
      styles.each do |style|
        puts "-- #{style}"
        # if the style is the same as the overview specs url slug
        # then we have already retrieved the page and we can just process it.
        if style == model['details'][year]['overview']['specs_url_slug']
          # process the html
          model['details'][year]['styles'][style] = process_specification_page(response_default_page.response_body)
        else
          response = Typhoeus.get(
            @specs_url.gsub('{slug}', style),
            :headers=>{"User-Agent" => @user_agent},
            followlocation: true, ssl_verifypeer: false, ssl_verifyhost: 0
          )

          # process the html
          model['details'][year]['styles'][style] = process_specification_page(response.response_body)

        end
      end
    end
  end

  puts model['details'].to_json

  puts "TOTAL TIME TO DOWNLOAD SPECIFICATIONS AND PARSE = #{((Time.now-start)/60).round(2)} minutes"

end



