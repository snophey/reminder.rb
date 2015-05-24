#! /usr/bin/ruby

require 'optparse'
require 'timers'
require 'time'
require 'csv'
require 'thread'
require 'socket'
require './notifiers.rb'

# remove old socket
if File.exist?(File.expand_path("~/.reminder/sock")) then
	File.delete(File.expand_path("~/.reminder/sock"))
end

$debug = true

def dbg_out(msg)
	if $debug then
		puts "DEBUG: #{msg}"
	end
end

def serialize()
	path = File.expand_path("~/.reminder")

	if not Dir.exist?(path) then
		Dir.mkdir(path)
	end

	datafile = File.open("#{path}/data.csv", "a")

	$notifiers.each do |key, group|
		group.each() do |notifier|
			# no need to serialize notifiers multiple times!
			if notifier.serialized then
				next
			end

			dbg_out "serializing \'#{key},#{notifier.s()}\'"
			cls = notifier.class.to_s.split('::')[1] # extract class name without module name
			datafile.write("#{key},#{notifier.s()},#{cls}\n")
			notifier.serialized = true
		end
	end

	datafile.close()
end

def read_data()
	path = File.expand_path("~/.reminder/data.csv")

	dbg_out "Reading data from: #{path}"

	if not File.exist?(path) then
		dbg_out "File does not exist."
		return
	end

	dbg_out "--> File exists. Reading..."
	CSV.foreach(path) do |row|
		read_row(row)
	end
end

def read_row(row, set_serialized_flag=true)
	key = row[0]
	title = row[1]
	message = row[2]
	type = row[3]
	dbg_out "Read #{key} -- #{title}: #{message} (#{type})"

	if DateTime.parse(key).to_time.gmtime <= DateTime.now.to_time.gmtime+Time.now.gmt_offset then
		dbg_out "--> This notifier has already expired. It won't be added"
		return
	end

	if NotifierTypes.const_defined?(type.to_sym) then
		if $notifiers[key].nil? then
			$notifiers[key] = []
		end

		notif = NotifierTypes.const_get(type.to_sym).new(title, message)
		# setting this flag makes sure the notifier will not be serialized again
		notif.serialized = set_serialized_flag
		$notifiers[key].push(notif)
	end
end

# hash of dates and arrays of corresponding notifiers
$notifiers = {}

read_data()

serialize()

timers = Timers::Group.new

every_minute = timers.every(30) do
	now = Time.new
	key = "%i.%i.%i %i:%i" % [now.day, now.month, now.year, now.hour, now.min]

	dbg_out "#{key}"

	$ex.synchronize do
		if not $notifiers[key].nil? then
			$notifiers[key].each do |notifier|
				notifier.notify()
			end
		end

		$notifiers.delete(key)
	end # ex.synchronize
end

$ex = Mutex.new
serv = UNIXServer.open(File.expand_path("~/.reminder/sock"))


# IPC code here
ipc = Thread.new do
	loop do
		s = serv.accept
		dbg_out "Accepted connection!"

		row = s.gets.chomp
		dbg_out "Client wrote: #{row}"
		row = CSV.parse_line(row)

		$ex.synchronize do
			read_row(row, false)
		end

		serialize()
	end
end

dbg_out "Starting main loop"
while true do #not $notifiers.empty? do
		timers.wait()
end

dbg_out "No more notifiers left. Exiting..."
