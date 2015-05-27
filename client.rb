require './notifiers.rb'
require 'time'
require 'socket'
require 'optparse'

$default_notifier = :NotifySend

# this hash will be reused later for command line options
$options = {}
$options[:notifier] = $default_notifier

def to_csv(key,notifier)
		cls = notifier.class.to_s.split('::')[1] # extract class name without module name
		return "#{key},#{notifier.s()},#{cls}"
end

def abs_time(time_str)
	return DateTime.parse(time_str)
end

def rel_time(hours,minutes)
	# adding whole numbers would add an entire day to the current time, hence the fractions
	return DateTime.now + Rational(hours*3600, 86400) + Rational(minutes*60, 86400)
end

OptionParser.new do |opts|
	opts.banner = "Usage: reminder.rb [options]"

	opts.on("-d", "--debug", "Enable debug output") do |v|
		$options[:verbose] = v
	end

	opts.on("-g","--guided", "Guided mode") do |g|
		$options[:guided] = g
	end

	opts.on("-iHH_MM", "--in=HH:MM", "Notify me in H hours and M minutes from now.") do |i|
		$options[:mode] = "i"
		offsets = i.split(":")
		$options[:time] = rel_time(Integer(offsets[0]), Integer(offsets[1]))
	end

	opts.on("-aDATETIME", "--at=DATETIME", "Notify me at a specified date and time.") do |a|
		$options[:mode] = "a"
		$options[:time] = abs_time(a)
	end

	opts.on("-nNOTIFIER", "--notifier=NOTIFIER", "Notification method. NotifySend if not explicitely specified.") do |n|
		$options[:notifier] = n
	end

	opts.on("-t[TITLE]", "--title=[TITLE]", "Title of the message.") do |t|
		$options[:title] = t || ""
	end

	opts.on("-mBODY", "--message=BODY", "Message body.") do |m|
		$options[:message] = m
	end

	opts.on("-h", "--help", "Prints this message") do
		puts opts
		exit
	end
end.parse!

puts $options

# this will be replaced by a function that parses command line options
def guided()

	#if $options[:notifier].nil? then
	#	print "Notifier (NotifySend): "
	#	$options[:notifier] = $stdin.gets.chomp
	#end

	if $options[:notifier].empty? or not NotifierTypes.const_defined?($options[:notifier].to_sym) then
		$options[:notifier] = $default_notifier
	end

	if $options[:mode].nil? then
		print "Mode (I/a): "
		$options[:mode] = $stdin.gets.chomp.downcase
	end

	if $options[:mode] != "a" then
		$options[:mode] = "i"
	end

	if $options[:title].nil? then
		print "Title (optional): "
		$options[:title] = $stdin.gets.chomp
	end

	if $options[:message].nil? then
		print "Message: "
		$options[:message] = $stdin.gets.chomp
	end

	if $options[:title].empty? then
		$options[:title] = "reminder.rb"
	end

	# make sure that we really get a message
	while $options[:message].empty? do
		print "Message: "
		$options[:message] = $stdin.gets.chomp
	end

	if $options[:time].nil? then
		if $options[:mode] == "a" then
			print "Time (DD.MM.YYYY HH:MM): "
			$options[:time] = abs_time($stdin.gets.chomp)
		elsif $options[:mode]
			puts "You want to be reminded in..."
			print "...hours: "
			hours = Integer($stdin.gets.chomp)
			print "...minutes: "
			minutes = Integer($stdin.gets.chomp)
			$options[:time] = rel_time(hours, minutes)
		end
	end
end

def gen_notifier()
	key = "#{$options[:time].day}.#{$options[:time].month}.#{$options[:time].year} #{$options[:time].hour}:#{$options[:time].min}"
	ntype = NotifierTypes.const_get($options[:notifier].to_sym)
	notifier = ntype.new($options[:title], $options[:message])

	return to_csv(key, notifier)
end

if $options[:guided] then
	guided()
end

sock = UNIXSocket.open(File.expand_path("~/.reminder/sock"))
sock.puts(gen_notifier())
sock.close()
