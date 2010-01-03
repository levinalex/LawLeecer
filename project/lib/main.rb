# Copyright (c) 2008, Tobias Vogel (tobias@vogel.name) (the "author" in the following)
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * The name of the author must not be used to endorse or promote products
#       derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# the programm returns wrong or no information, if
# - the website was changed
# - there are more than 10000 laws per type
# - entries contain a # in the text

require 'core.rb'

theCore = Core.createInstance

# first, determine, whether we want to have a GUI
if (ARGV.member? "--nogui")
  Configuration.guiEnabled = false

  ARGV.each { |argument|
    case argument
    when /--startyear=.+/
      argument = argument.gsub /--startyear=/, ''
      if argument.nil? or argument.empty? then break end
      argument = argument.to_i
      if argument > Configuration.startYear and argument <= Time.now.year
        Configuration.startYear = argument
        Configuration.log_verbose "Start year set to #{Configuration.startYear}"
      else
        Configuration.log_default "Warning: desired start year (#{argument}) is in the future. Using #{Configuration.startYear} instead."
      end

    when /--numberofthreads=.+/
      argument = argument.gsub /--numberofthreads=/, ''
      if argument.nil? or argument.empty? then break end
      argument = argument.to_i
      Configuration.numberOfParserThreads = argument if argument >= 1 and argument < 100
      Configuration.log_verbose  "Number of threads set to #{Configuration.numberOfParserThreads}"

    when /--filename=.+/
      argument.gsub! /--filename=/, ''
      Configuration.filename = argument unless argument.nil? or argument.empty?
      Configuration.log_verbose "Filename set to #{Configuration.filename}"

    when /--overwriteexistingfile/
      Configuration.overwritePermission = true
      Configuration.log_verbose "Overwrite existing file set to #{Configuration.overwritePermission}"

    when /--loglevel=.+/
      argument = argument.gsub /--loglevel=/, ''
      Configuration.loglevel = case argument
        when /verbose/i then Configuration::VERBOSE
        when /default/i then Configuration::DEFAULT
        when /quiet/i then Configuration::QUIET
        else begin
          $stderr.puts "Unrecognized log level \"#{argument}\". Exiting."
          exit
        end
      end
      Configuration.log_verbose "Log level set to #{Configuration.loglevel}"

    when /--nogui/
      # this parameter is OK, but leave it here for readability

    else
      $stderr.puts "Unknown command line parameter: \"#{argument}\". Exiting."
      exit
    end
  }

  theCore.startProcess



else
  puts 'System starts in GUI mode. Command line parameters are ignored.'
  require 'g_u_i.rb'

  gui = GUI.createInstance

  begin
    gui.run
  rescue
    puts $!
  end
end