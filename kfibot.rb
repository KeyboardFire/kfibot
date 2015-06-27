#!/usr/bin/ruby

require 'cinch'
require 'cinch/plugins/identify'
require 'sqlite3'
require 'open3'

$botnick = open('username').read

# a bunch of ugly hacks...
class Cinch::Callback
    def reply m, txt, suppress_ping=false
        txt = "#{m.user.nick}: " + txt unless suppress_ping
        File.open('log.txt', 'a+') {|f|
            f.puts "[#{m.time}] <#{$botnick}> #{txt}"
        }
        m.reply txt
    end
end
$whois_return = nil
class Cinch::IRC
    alias old_on_318 on_318
    alias old_on_330 on_330
    def on_318 msg, events
        $whois_return = [nil, nil, nil, nil] unless $whois_return
        old_on_318 msg, events
    end
    def on_330 msg, events
        $whois_return = msg.params
        old_on_330 msg, events
    end
end
def query_whois user
    $whois_return = nil
    bot.irc.send "whois #{user}"
    sleep 0.1 until $whois_return
    p $whois_return
    r = $whois_return
    $whois_return = nil
    r[2]
end

bot = Cinch::Bot.new do
    prefix = '!'

    configure do |c|
        c.server = 'irc.freenode.org'
        c.nick = $botnick
        c.channels = []
        c.plugins.plugins = [Cinch::Plugins::Identify]
        c.plugins.options[Cinch::Plugins::Identify] = {
            :username => $botnick,
            :password => open('password').read,
            :type => :nickserv
        }
    end

    db = SQLite3::Database.new 'learn.db'

    db.execute <<-SQL
        create table if not exists LearnDb (
            key TEXT,
            val TEXT
        );
    SQL

    on :message, /(.*)/ do |m, txt|
        File.open('log.txt', 'a+') {|f|
            f.puts "[#{m.time}] <#{m.user.nick}> #{txt}"
        }

        if txt[0...prefix.length] == prefix
            txt = txt[prefix.length..-1]
            cmd, args = txt.split ' ', 2
            if cmd == 'restart'  # special-case
                reply m, 'restarting bot...'
                bot.quit("restarting (restarted by #{m.user.nick})")
                sleep 0.1 while bot.quitting
                # you're supposed to run this in a loop
                # while :; do ./kfibot.rb; done
            end
            unless cmd.nil?  # message might consist of only prefix...
                val = db.execute('select val from LearnDb where key = ?', cmd).first
                if val.nil?
                    reply m, "unknown command #{cmd}"
                else
                    val = val.first
                    if val == '$RUBY_IMPL'
                        Open3.popen3("ruby #{cmd}.rb") do |stdin, stdout, stderr|
                            stdin.puts args
                            while line = stdout.gets
                                line = line.chomp
                                if line == '$REQUEST_WHOIS'
                                    w = query_whois m.user.nick
                                    stdin.puts w
                                else
                                    reply m, line
                                end
                            end
                            stdin.close_write
                        end
                    else
                        reply m, val
                    end
                end
            end
        end
    end

    on :notice do |m|
        if m.message.index 'You are now identified for'
            bot.join '##kbdfire-bottest'
        end
    end

    on :join do |m|
        if m.user.nick == $botnick
            reply m, 'Bot started.', true
        else
            reply m, 'welcome! I am a robit. Type !help to get assistance ' +
                'on how to use me.'
        end
    end
end

bot.start
