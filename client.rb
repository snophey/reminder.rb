require './notifiers.rb'
require 'time'
require 'socket'

$default_notifier = :NotifySend

# this hash will be reused later for command line options
$options = {}

def to_csv(key,notifier)
		cls = notifier.class.to_s.split('::')[1] # extract class name without module name
		return "#{key},#{notifier.s()},#{cls}"
end

# this will be replaced by a function that parses command line options
def read_options()

	print "Notifier (NotifySend): "
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
  ntype = NotifierTypes.const_get($options["notifier"].to_sym)
	notifier = ntype.new($options["title"], $options["message"])

  return to_csv(key,notifier)
end

sock = UNIXSocket.open(File.expand_path("~/.reminder/sock"))
sock.puts(read_options())
sock.close()
