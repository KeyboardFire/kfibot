args = gets.chomp

puts '$REQUEST_CHANNEL'
STDOUT.flush
chan = gets.chomp

case args
when /^(add|del) ([^ ]+)$/i
    add = $1.downcase == 'add'
    puts "$REQUEST_SEND_CMD mode #{chan} #{add ? ?+ : ?-}q #{$2}"
when /^list$/i
    puts 'list of muted users:'
    puts '$REQUEST_EVAL $echo_mutes = true'
    puts "$REQUEST_SEND_CMD mode #{chan} +q"
else
    puts 'usage: !mute {ADD|DEL} {mask} or !mute LIST'
end
