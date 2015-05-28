
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
		return "\"#{@title}\",\"#{@message}\""
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
		if title.nil? || title.empty? then
			title = "reminder.rb"
		end
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
		system("zenity --info --text \"#{@message}\" &")
	end
end

end
