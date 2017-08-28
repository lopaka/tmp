#!/usr/bin/ruby

require 'sequel'
require 'csv'

# defaults to april 2017
year = '2017'
month = '04'

# Check that environment variables are set for authentication
raise 'AUTHENTICATION VARS MISSING' if ENV['DB_HOST_NAME'].nil? || ENV['DB_USERNAME'].nil? || ENV['DB_PASSWORD'].nil?

# DB Host
hostname = ENV['DB_HOST_NAME']
# DB username
username = ENV['DB_USERNAME']
# DB pass
pass = ENV['DB_PASSWORD']

# Generate DB object
db = Sequel.connect(
  adapter: 'mysql2',
  database: 'parking_lot',
  user: username,
  host: hostname,
  password: pass
)

# Obtain all entries that parked in the month in question
parking_lot_month = db["SELECT license, time_in, time_out FROM lot WHERE time_out >= '#{year}-#{month}-01' OR time_out = '0000-00-00 00:00:00'"].all

# Calculate totals and place into hash with license as key
total_hours = {}
parking_lot_month.each do |car|
  total_hours[car[:license]] ||= 0

  # Determine start time for calculations
  start_time =
    if car[:time_in] < Time.new(year.to_i, month.to_i)
      Time.new(year.to_i, month.to_i)
    else
      # For time_in, start at the beginning of the hour
      Time.new(
        car[:time_in].year,
        car[:time_in].month,
        car[:time_in].day,
        car[:time_in].hour,
        0, # minute
        0 # second
      )
    end

  # Determine end time for calculations
  end_time =
    if car[:time_out].nil? # date is set to 0000-00-00 00:00:00 in db
      Time.parse(Date.new(year.to_i, month.to_i).next_month.to_s) # start of next month meaning end of billing month
    else
      # For time_out, round up to the end of the hour
      rounded_time_out = car[:time_out] + 3600
      Time.new(
        rounded_time_out.year,
        rounded_time_out.month,
        rounded_time_out.day,
        rounded_time_out.hour,
        0, # minute
        0 # second
      )
    end

  # Calculate time diff and add to hash
  total_hours[car[:license]] += ((end_time - start_time).to_i / 3600).to_i
end

# Generate csv string
csv_output = %w[car_owner license hours].to_csv # Header
total_hours.each do |license, hours|
  # Grab car owner's name - using Sequel toolkit syntax ( see http://sequel.jeremyevans.net/ )
  car_owner = db[:accounts].where(license: license).get(:first_last_name)
  csv_output << [car_owner, license, hours].to_csv
end
# Print out CSV
puts csv_output
