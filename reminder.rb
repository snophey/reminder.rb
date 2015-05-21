#! /usr/bin/ruby

$default_notifier = :Zenity

require 'optparse'
require 'timers'
require 'time'
require 'csv'

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
		key = row[0]
		title = row[1]
		message = row[2]
		type = row[3]
		dbg_out "\nRead #{key} -- #{title}: #{message} (#{type})"

		if DateTime.parse(key).to_time.gmtime <= DateTime.now.to_time.gmtime+Time.now.gmt_offset then
			dbg_out "--> This notifier has already expired. It won't be added."
			next
		end

		if NotifierTypes.const_defined?(type.to_sym) then
			if $notifiers[key].nil? then
				$notifiers[key] = []
			end

			notif = NotifierTypes.const_get(type.to_sym).new(title, message)
			# setting this flag makes sure the notifier will not be serialized again
			notif.serialized = true
			$notifiers[key].push(notif)
		end
	end
end

module NotifierTypes

class Notifier
	attr_accessor :serialized

	def initialize(title, message)
		@title = title
		@message = message
		@serialized = false
	end

	def notify()
	end

	def s()
		return "#{@title},#{@message}"
	end
end

# command line notifier
class CLNotifier < Notifier
	def initialize(title, message)
		super(title, message)
	end

	def notify()
		dbg_out "#{@title.upcase}: #{@message}"
	end
end

class NotifySend < Notifier
	def initialize(title, message)
		super(title, message)
	end

	def notify()
		system("notify-send \"#{@title}\" \"#{@message}\"")
	end
end

class Zenity < Notifier
	def initialize(title, message)
		super(title, message)
	end

	def notify()
		system("zenity --info --text \"#{@message}\"")
	end
end

end

# hash of dates and arrays of corresponding notifiers
$notifiers = {}

# this hash will be reused later for command line options
$options = {}

# this will be replaced by a function that parses command line options
def read_options()

	print "Notifier (Zenity): "
	$options["notifier"] = $stdin.gets.chomp

	if $options["notifier"].empty? or not NotifierTypes.const_defined?($options["notifier"].to_sym) then
		$options["notifier"] = $default_notifier
	end

	print "Mode (I/a): "
	$options["mode"] = $stdin.gets.chomp.downcase

	if $options["mode"] != "a" then
		$options["mode"] = "i"
	end

	print "Title (optional): "
	$options["title"] = $stdin.gets.chomp
	print "Message: "
	$options["message"] = $stdin.gets.chomp

	if $options["title"].empty? then
		$options["title"] = "reminder.rb"
	end

	while $options["message"].empty? do
		print "Message: "
		$options["message"] = $stdin.gets.chomp
	end

	if $options["mode"] == "a" then
		print "Time (DD.MM.YYYY HH:MM): "
		$options["time"] = DateTime.parse($stdin.gets.chomp)
	else
		puts "You want to be reminded in..."
		print "...hours: "
		hours = Integer($stdin.gets.chomp)*3600
		print "...minutes: "
		minutes = Integer($stdin.gets.chomp)*60
		# adding whole numbers would add an entire day to the current time, hence the fractions
		$options["time"] = DateTime.now + Rational(hours, 86400) + Rational(minutes, 86400)
	end

	key = "#{$options["time"].day}.#{$options["time"].month}.#{$options["time"].year} #{$options["time"].hour}:#{$options["time"].min}"

	if $notifiers[key].nil? then
		$notifiers[key] = []
	end

	dbg_out "adding notifier for key: '#{key}'"

	ntype = NotifierTypes.const_get($options["notifier"].to_sym)
	$notifiers[key].push(ntype.new($options["title"], $options["message"]))
end

read_data()
read_options()

serialize()

timers = Timers::Group.new

every_minute = timers.every(30) do
	now = Time.new
	key = "%i.%i.%i %i:%i" % [now.day, now.month, now.year, now.hour, now.min]

	dbg_out "#{key}"

	if not $notifiers[key].nil? then
		$notifiers[key].each do |notifier|
			notifier.notify()
		end
	end

	$notifiers.delete(key)
end


while not $notifiers.empty? do
	timers.wait()
end
