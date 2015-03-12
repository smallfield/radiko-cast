# coding: utf-8
require "yaml"
require "pp"
require "rss"
require "date"
require "slim"
require "logger"

class RadikoCast
	FILE_TIME_FORMAT = "%Y-%m-%d-%H_%M"
	RSS_TIME_FORMAT  = "%a, %d %b %Y %H:%M:%S %z"
	DAY_JAPANESE     = %w[日 月 火 水 木 金 土]

	def initialize
		@pwd           = File.expand_path("../", __FILE__)
		@conf          = YAML.load_file(File.expand_path("#{@pwd}/conf.yml", __FILE__))
		@web_root_dir  = "#{@pwd}/public"
		@enclosure_dir = "#{@web_root_dir}/enclosure"
		@enclosure_url = "#{@conf["podcast"]["url"]}enclosure/"
		@ruby_log_file = "#{@pwd}/log/ruby.log"
		@sh_log_file   = "#{@pwd}/log/shell.log"
		@logger        = Logger.new(STDOUT)
		@logger.level  = Logger::INFO
		# 週の中での放送が早い順にソート
		@conf["recordings"] = @conf["recordings"].sort{|(_, v1), (_, v2)|
			format("#%d%02d%02d", DAY_JAPANESE.index(v1["day"]), v1["hour"], v1["min"]) <=>
			format("#%d%02d%02d", DAY_JAPANESE.index(v2["day"]), v2["hour"], v2["min"])
		}
	end

	def configureCron
		@logger.info "create cron config: #{@conf["cron"]["file"]}"
		crond = File.open @conf["cron"]["file"], 'w'
		crond.puts "PATH=#{@conf["cron"]["path"]}"
		crond.puts "LANG=ja_JP.UTF-8"
		crond.puts "*/15 * * * *   #{@conf["cron"]["user"]} ruby #{File.expand_path(".", __FILE__)} 2>&1 >> #{@ruby_log_file}"
		@conf["recordings"].each do |name, rec|
			crond.puts "#{getCronString rec} #{@conf["cron"]["user"]} #{@pwd}/#{@conf["script_name"]} #{rec["channel"]} #{rec["duration"]} #{@enclosure_dir} #{name} 2>&1 >> #{@sh_log_file}"
		end
		crond.close
	end

	def getCronString(data)
		format "%-3d%-3d * * %-3d" ,data["min"], data["hour"], DAY_JAPANESE.index(data["day"])
	end

	def getScheduleString(data)
		format "毎週%s曜日 %d:%02dから(%s)", data["day"], data["hour"], data["min"], data["channel"]
	end

	def generateFeed
		@conf["recordings"].each do |name, rec|
			@logger.info "creating RSS for #{rec["name"]}"
			rss = RSS::Maker.make("2.0") do |maker|
				maker.channel.description = "#{rec["name"]}\n#{getScheduleString rec}"
				maker.channel.generator   = "radiko-cast"
				maker.channel.language    = "ja-jp"
				maker.channel.link        = @conf["podcast"]["url"]
				maker.channel.pubDate     = DateTime.now.strftime(RSS_TIME_FORMAT)
				maker.channel.title       = rec["name"]
				maker.items.do_sort       = true
				Dir::entries(@enclosure_dir).each do |file|
					if /^#{name}_(\d{4}-\d{2}-\d{2}-\d{2}_\d{2})/ =~ file
						onair = DateTime.strptime("#{$~[1]}+09:00","#{FILE_TIME_FORMAT}%z")
						item = maker.items.new_item
						item.title            = onair.strftime("%Y年%m月%d日 放送分")
						item.description      = "#{rec["name"]} #{item.title}"
						item.link             = @conf["podcast"]["url"]
						item.pubDate          = onair.strftime()
						item.guid.content     = "#{name}:#{onair.strftime(FILE_TIME_FORMAT)}"
						item.guid.isPermaLink = false
						item.enclosure.url    = "#{@enclosure_url}#{file}"
						item.enclosure.type   = "audio/mpeg"
						item.enclosure.length = File.size("#{@enclosure_dir}/#{file}")
					end
				end
			end
			out = File.new("#{@web_root_dir}/#{name}.xml", "w")
			out.puts rss.to_s
			out.close
			# puts rss.to_s
		end
	end

	def generateIndex
		@logger.info "writing index.html"
		schedule = {}
		last_update = {}
		@conf["recordings"].each do |name, data|
			schedule[name] = getScheduleString(data)
		end
		index = File.new("#{@web_root_dir}/index.html", "w")
		index.puts Slim::Template.new("#{@pwd}/index.slim").render(self, :recordings => @conf["recordings"], :conf => @conf, :schedule => schedule)
		index.close
	end
end

radiko = RadikoCast.new

if ARGV.size == 1
	case ARGV[1]
	when "cron"
		radiko.configureCron
	when "index"
		radiko.generateIndex
	when "feed"
		radiko.generateFeed
	end
else
	radiko.configureCron
	radiko.generateIndex
	radiko.generateFeed
end
