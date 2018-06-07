# files
@all_cars_file = "data/all_cars.json"
@all_cars_file_with_years = "data/all_cars_with_years.json"
@all_cars_file_with_years_overview = "data/all_cars_with_years_overview.json"
@all_cars_file_with_years_overview_styles = "data/all_cars_with_years_overview_styles.json"
@all_cars_file_with_years_overview_styles_specs = "data/all_cars_with_years_overview_styles_specs.json"
@csv_data = 'data/car_data.csv'

# urls
@model_years_url = 'https://www.thecarconnection.com/showroom-ajax/load-available-years?modelId='
@overiew_url = 'https://www.thecarconnection.com/overview/{car}_{model}_{year}'
@specs_url = 'https://www.thecarconnection.com/specifications/{slug}'
# @specs_slug = '{car}_{model}_{year}_{style}'

@user_agent = "Mozilla/5.0 (Windows NT 10.0; WOW64; rv:60.0) Gecko/20100101 Firefox/60.0"
@max_concurrency = 10

@expert_ratings = {
  'Styling' => 'styling',
  'Performance' => 'performance',
  'Comfort & Quality' => 'comfort_quality',
  'Safety' => 'safety',
  'Features' => 'features',
  'Fuel Economy' => 'fuel_economy',
}

# data csv headers
@csv_headers = [
  'car',
  'model',
  'year',
  'style',
  'expert_ranking_number',
  'expert_ranking_category',
  'used_reviews_rating',
  'used_reviews_number',
  'expert_rating_overview',
  'expert_rating_styling',
  'expert_rating_performance',
  'expert_rating_comfort_quality',
  'expert_rating_safety',
  'expert_rating_features',
  'expert_rating_fuel_economy',
  'expert_likes',
  'expert_dislikes',
  'used_price_range',
  'msrp',
  'body_style',
  'passenger_doors',
  'transmission',
  'epa_classification',
  'passenger_capacity',
  'front_head_room',
  'front_shoulder_room',
  'front_hip_room',
  'front_leg_room',
  'second_head_room',
  'second_shoulder_room',
  'second_hip_room',
  'second_leg_room',
  'third_head_room',
  'third_shoulder_room',
  'third_hip_room',
  'third_leg_room',
  'width',
  'height',
  'length',
  'ground_clearance',
  'trunk_volume',
  'cargo_area_width',
  'cargo_area_height',
  'cargo_area_length_floor_to_seat2',
  'cargo_area_volume_to_seat1',
  'cargo_area_volume_to_seat2',
  'cargo_are_volume_to_seat3',
  'fuel_tank_capacity',
  'mpg_city',
  'mpg_highway',
  'mpg_combined',
  'battery_range',
  'mpg_equivalent_city',
  'mpg_equivalent_hwy',
  'mpg_equivalent_combined',
  'engine_type',
  'engine_displacement',
  'horsepower',
  'fuel_system',
  'brakes_abs',
  'brakes_disc_front',
  'brakes_disc_rear',
  'brakes_drum_rear',
  'steering_type',
  'turning_diameter',
  'air_bag_front_driver',
  'air_bag_front_passenger',
  'air_bag_front_passenger_switch',
  'air_bag_side_head_front',
  'air_bag_side_body_front',
  'air_bag_side_head_rear',
  'air_bag_side_body_rear',
  'child_door_locks',
  'other_features'

]


