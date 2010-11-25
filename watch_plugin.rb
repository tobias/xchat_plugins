# -*- coding: utf-8 -*-
# A xchat plugin that does the following:
# - on a mention of your nick:
#   - it highlights the full message (black on yellow, bolded)
#   - it pops up a critical libnotify notification for 1 minute, and plays a
#     sound
# - it pops up a standard libnotify notification on any message to one
#   of the watched channels
#
# This plugin requires the XChat-Ruby plugin to be loaded
# (http://xchat-ruby.sourceforge.net/). Once XChat-Ruby is loaded, you
# can load this plugin with:
# /rb load /path/to/watch_plugin.rb
#
# If you are not me, you will want to adjust the constants below.
#
# Author: tcrawley@gmail.com
# Home: http://github.com/tobias/xchat_plugins
include XChatRuby

class Watch < XChatRubyPlugin
  MPLAYER = '/usr/bin/mplayer'
  ALERT_SOUND = '/usr/lib64/openoffice.org/basis3.3/share/gallery/sounds/apert.wav'
  CHANNEL_FILE = '/home/tcrawley/.xchat2/watched_channels'
  NOTIFY_BIN = '/usr/bin/notify-send'

  attr_reader :channels

  def initialize
    @plugin_name = format('![bc(yellow)]Watch![bc]')
    load_channels
    hook_command('Watch', XCHAT_PRI_NORM, method(:watch_handler) ,
                 'Usage: /watch cmd opts, see /watch help for more info')

    ["Channel Message",
     "Channel Msg Hilight",
     "Channel Action",
     "Channel Action Hilight",
     "Private Message"].each do |event|
      hook_print(event, XCHAT_PRI_NORM, method(:message_handler), event)
    end

    puts_msg "loaded ('/watch help' for more info)."
  end

  def message_handler(words, data)
    channel = get_info('channel')
    nick = get_info('nick')
    mention = words[1] =~ /#{nick}/
    if channels.include?(channel) or
        mention
      title = "<#{words[0]}> on #{channel}"
      notify(title, words[1], mention)
      play_sound if mention
    end

    mention ? hilight_full_message(words, nick, data) : XCHAT_EAT_NONE
  end

  def notify(title, message, sticky = false)
    command = "#{NOTIFY_BIN} #{sticky ? '-t 60000 -u critical' : ''} \"#{format_for_notify(title)}\" \"#{format_for_notify(message)}\""
    %x{#{command}}
  end

  def play_sound
    %x{#{MPLAYER} #{ALERT_SOUND}}
  end

  def format_for_notify(text)
    strip_mirc(text.gsub('"', '\"').gsub("&", "&amp;").gsub('$', '\$'))
  end

  def strip_mirc(text)
    text.gsub(/(\d*|\d+,\d+)/, '')
  end

  def hilight_full_message(words, nick, data)
    if words[1] =~ /#{nick}/
      if data =~ /Action/
        gutter = "»»"
        message = "#{words[0]} #{words[1]}"
      else
        gutter = "<#{words[0]}>"
        message = words[1]
      end
      puts_fmt("![c(black),(yellow)b]#{gutter}![|]#{message}![cb]")
      XCHAT_EAT_XCHAT
    else
      XCHAT_EAT_NONE
    end
  end

  def watch_handler( words, words_eol, data )
    case words[1] && words[1].downcase
    when 'add'
      add_channel(words_eol[2])
    when 'remove'
      remove_channel(words_eol[2])
    when 'list'
      list_channels
    when 'help'
      print_help
    else
      puts "Unrecognized command. Try '/watch help'"
    end

    XCHAT_EAT_ALL
  end

  def add_channel(channel)
    if channel
      if @channels.include?(channel)
        puts_msg "#{channel} is already on the watch list"
      else
        @channels << channel
        save_channels
        puts_msg "#{channel} added to the watch list"
      end
    else
      puts_msg "a channel argument is required"
      print_help
    end

    XCHAT_EAT_ALL
  end

  def remove_channel(channel)
    if channel
      if @channels.include?(channel)
        @channels.delete(channel)
        save_channels
        puts_msg "#{channel} removed from the watch list"
      else
        puts_msg "#{channel} is not on the watch list"
      end
    else
      puts_msg "a channel argument is required"
      print_help
    end

    XCHAT_EAT_ALL
  end

  def list_channels
    list = "Watched channels:\n"
    @channels.each do |channel|
      list << "  - #{channel}\n"
    end
    puts_msg list

    XCHAT_EAT_ALL
  end

  def print_help
    puts <<EOT

#{@plugin_name} -- a notification plugin for XChat2
Available commands:

  /watch add #channel      -- adds a channel to be watched
         remove #channel    -- removes a channel from the watch list
         list               -- lists the currently watched channels
         help               -- shows this text
EOT

  end

  def load_channels
    if File.exists?(CHANNEL_FILE)
      File.open(CHANNEL_FILE, 'r') do |f|
        @channels = f.readlines.map { |c| c.strip }
      end
    end
    @channels ||= []
  end

  def save_channels
    File.open(CHANNEL_FILE, 'w') do |f|
      @channels.each do |c|
        f.write("#{c}\n")
      end
    end
  end

  def puts_msg(msg)
    puts "#{@plugin_name}: #{msg}"
  end
end
