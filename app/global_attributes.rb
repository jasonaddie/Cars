# files
@all_cars_file = "data/all_cars.json"
@all_cars_file_with_years = "data/all_cars_with_years.json"
@all_cars_file_with_years_overview = "data/all_cars_with_years_overview.json"
@csv_data = 'data.csv'

# urls
@model_years_url = 'https://www.thecarconnection.com/showroom-ajax/load-available-years?modelId='
@overiew_url = 'https://www.thecarconnection.com/overview/{car}_{model}_{year}'
@specs_url = 'https://www.thecarconnection.com/specification/{car}_{model}_{year}_{style}'

@user_agent = "Mozilla/5.0 (Windows NT 10.0; WOW64; rv:54.0) Gecko/20100101 Firefox/54.0"

@expert_ratings = {
  'Styling' => 'styling',
  'Performance' => 'performance',
  'Comfort & Quality' => 'comfort_quality',
  'Safety' => 'safety',
  'Features' => 'features',
  'Fuel Economy' => 'fuel_economy',
}

# detail csv headers
@csv_headers = [
  'record_id',
  'last name',
  'first name',
  'middle name',
  'birth_date',
  'place of birth',
  'date/place of recruitment',
  'last place of service',
  'military rank',
  'death reason',
  'death date',
  'initial burial location',
  'source name',
  'source fund number',
  'source description number',
  'source file number',
  'source image url'
]


