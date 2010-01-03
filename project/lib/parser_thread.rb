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

class ParserThread

  # does the overall parsing task
  def retrieveAndParseALaw lawID
    @lawID = lawID
    Configuration.log_verbose "#{@lawID}: start"

    begin # start try block

      response = fetch("http://ec.europa.eu/prelex/detail_dossier_real.cfm?CL=en&DosId=#{@lawID}")
      @content = response.body

      # prepare array containing all information for the current law
      arrayEntry = {}

      # check, whether some specific errors occured
      if @content[/<H1>Database Error<\/H1>/]
        $stderr.print "#{@lawID}: is empty. (Produces a data base error)\n"
        Core.createInstance.callback({'status' => "Das Gesetz #{@lawID} kann nicht gelesen werden und wird ignoriert."})
        return
      end

      if @content[/<H1>Unexpected Error<\/H1>/]
        $stderr.print "#{@lawID}: is empty. (Produces an \"unexpected error\")\n"
        Core.createInstance.callback({'status' => "Das Gesetz #{@lawID} kann nicht gelesen werden und wird ignoriert."})
        return
      end

      # check, whether fields of activity follows events immediately: then, it is empty
      if @content[/<strong>&nbsp;&nbsp;Events:<\/strong><br><br>\s*<table border="0" cellpadding="0" cellspacing="1">\s*<\/table>/]
        $stderr.print "#{@lawID}: is empty. (Contains no values)\n"
        Core.createInstance.callback({'status' => "Das Gesetz #{@lawID} kann nicht gelesen werden und wird ignoriert."})
        return
      end



      # now, find out many different pieces of information
      arrayEntry[Configuration::BLUEBOX_UPPERLEFTIDENTIFIER] = parseSimple(/<table BORDER=\"0\" WIDTH=\"100%\" bgcolor=\"#C0C0FF\">\s*<tr>\s*<td>\s*<table CELLPADDING=2 WIDTH=\"100%\" Border=\"0\">\s*<tr>\s*<td ALIGN=LEFT VALIGN=TOP WIDTH=\"50%\">\s*<b><font face=\"Arial\"><font size=-1>/, /.*?(?=<\/font><\/font><\/b>\s*<\/td>)/, @content)
      arrayEntry[Configuration::BLUEBOX_UPPERCENTERIDENTIFIER] = parseSimple(/<\/font><\/font><\/b>\s*<\/td>\s*<td ALIGN=LEFT VALIGN=TOP WIDTH=\"50%\">\s*<b><font face=\"Arial\"><font size=-1>/, /.*?(?=<\/font><\/font><\/b>\s*<\/td>\s*<td ALIGN=RIGHT VALIGN=TOP>\s*<\/td>\s*<\/tr>\s*<tr>\s*<td ALIGN=LEFT VALIGN=TOP COLSPAN=\"3\" WIDTH=\"100%\">\s*<font face="Arial"><font size=-2>)/, @content)
      arrayEntry[Configuration::BLUEBOX_SHORTDESCRIPTION] = parseSimple(/<\/font><\/font><\/b>\s*<\/td>\s*<td ALIGN=RIGHT VALIGN=TOP>\s*<\/td>\s*<\/tr>\s*<tr>\s*<td ALIGN=LEFT VALIGN=TOP COLSPAN=\"3\" WIDTH=\"100%\">\s*<font face="Arial"><font size=-2>/, /.*?(?=<\/font><\/font>\s*<\/td>\s*<\/tr>)/, @content)

      arrayEntry[Configuration::TYPE] = parseSimple(/<font face="Arial">\s*<font size=-1>(\d{4}\/)?\d{4}\//, /(CNS|COD|SYN|AVC|ACC|PRT|CNB|CNC)(?=<\/font>\s*<\/font>)/, @content)

      arrayEntry[Configuration::GREENBOX_FIELDSOFACTIVITY] = parseSimple(/Fields of activity:<\/font>\s*<\/center>\s*<\/td>\s*<td BGCOLOR="#EEEEEE">\s*<font face="Arial,Helvetica" size=-2>\s*/, /.*?(?=<\/tr>)/, @content)
      arrayEntry[Configuration::GREENBOX_LEGALBASIS] = parseSimple(/Legal basis:\s*<\/font>\s*<\/center>\s*<\/td>\s*<td BGCOLOR="#FFFFFF">\s*<font face="Arial,Helvetica" size=-2>/, /.*?(?=<\/tr>)/, @content)
      arrayEntry[Configuration::GREENBOX_PROCEDURES] = parseSimple(/Procedures:<\/font>\s*<\/center>\s*<\/td>\s*<td BGCOLOR="#EEEEEE">\s*<font face="Arial,Helvetica" size=-2>/, /.*?(?=<\/tr>)/, @content)
      arrayEntry[Configuration::GREENBOX_TYPEOFFILE] = parseSimple(/Type of file:<\/font>\s*<\/center>\s*<\/td>\s*<td BGCOLOR="#FFFFFF">\s*<font face="Arial,Helvetica" size=-2>/, /.*?(?=<\/tr>)/, @content)

      # timeline items (timestamp, title, and (if available) decision (mode) value)
      allTables = @content[/<table BORDER=0 CELLSPACING=0 COLS=2 WIDTH="100%" BGCOLOR="#EEEEEE" >.*<\/td>\s*<\/tr>\s*<\/table>\s*<!-- BOTTOM NAVIGATION BAR -->/m]
      # separate the tables, each table is an entry in the timeline
      allTables = allTables.split(/(?=<table BORDER=0 CELLSPACING=0 WIDTH="100%" BGCOLOR="#.{6}")/)
      # remove the first one (green table)
      allTables.shift

      arrayEntry[Configuration::TIMELINE] = processTimeline allTables

      # first box items (whatever is in there)
      arrayEntry[Configuration::FIRSTBOX] = processFirstBox allTables.first

      # last box items (if available)
      arrayEntry[Configuration::LASTBOX_DOCUMENTS], arrayEntry[Configuration::LASTBOX_PROCEDURES], arrayEntry[Configuration::LASTBOX_TYPEOFFILE], arrayEntry[Configuration::LASTBOX_NUMEROCELEX] = processLastBox allTables.last

      arrayEntry[Configuration::ID] = @lawID

    rescue Exception => ex
      $stderr.puts "EXCEPTION in law ##{@lawID}"
      $stderr.puts ex.message
      $stderr.puts ex.class
      $stderr.puts ex.backtrace

      if ex.class == Errno::ECONNRESET or ex.class == Timeout::Error or ex.class == EOFError
        Configuration.log_verbose "#{@lawID}: timeout, starting this law again"
        retry
#      elsif ex.class == Net::HTTPBadResponse
#        Configuration.log_verbose "#{@lawID}: bad HTTP response, stating this law again"
#        retry
      elsif ex.message == 'empty law'
        Configuration.log_verbose "#{@lawID}: empty, will be ignored"
      else
        Configuration.log_verbose "#{@lawID}: error, will be ignored"
        #return @lawID
      end
    end #of exception handling

    Configuration.log_verbose "#{@lawID}: end"
    return arrayEntry
  end





  private

  # process all timeline items (all these tables in the center of the page)
  def processTimeline allTables
    timeline = []

    # retrieve data from each table
    allTables.each { |table|
      # separate the table into table rows (<tr>)
      rows = table.split(/(?=<tr>)/)

      # remove the stuff before the first <tr>
      rows.shift

      # the first <tr>... contains the date and the title of the timeline step
      firstRow = rows.shift
      timestamp = firstRow[/\d\d-\d\d-\d\d\d\d(?=<\/B>\s*<\/font>)/]
      title = parseSimple(/<td ALIGN=CENTER WIDTH=\"\d+%\" BGCOLOR=\"#.{6}\">\s*<font face=\"Arial\">\s*<font size=-2>\s*<B>/, /.*(?=<\/B>\s*<\/font>\s*<\/font>\s*<\/td>\s*<\/tr>\s*)/, firstRow)


      decision = Configuration.missingEntry
      unless rows.empty?
        # the second <tr>... contains "decision" or "decision mode" or none of both
        secondRow = rows.shift
        secondRow.gsub! /<tr>\s*<td width=\"3\">&nbsp;<\/td>\s*<td VALIGN=TOP><font face=\"Arial\"><font size=-2>/, ''
        decision = secondRow[/^Decision (mode)?:/]
        if decision.nil?
          decision = Configuration.missingEntry
        else
          decision = parseSimple(/<font size=-2>/, /.*<\/font><\/font><\/td>\s*<\/tr>/, secondRow)
        end
      end

      timeline << {'titleOfStep' => title, 'timestamp' => timestamp, 'decision' => decision}
    }

    return timeline
  end





  # process the last table of the many piled up tables in the center of the page
  def processLastBox lastTable
    rows = lastTable.split(/(?=<tr>)/)
    # remove the stuff before the first <tr>, immediately
    rows.shift

    # if this table is empty, there is only one <tr> holding the table header

    documents = Configuration.missingEntry
    procedures = Configuration.missingEntry
    typeOfFile = Configuration.missingEntry
    numeroCelex = Configuration.missingEntry

    rows.each { |row|
      if row[/Documents:/]
        # there can be several documents, thus: split it
        documents = row.split /<BR>/
        documents.pop
        documents.collect! {|document|
          parseSimple(/.*<font size=-2>/, /.*(?=<\/font><\/font>\s*(<\/a>)?)/, document)
        }

        documents = documents.join Configuration.innerSeparator
      end

      if row[/Procedures/]
        procedures = parseSimple(/Procedures:<\/font><\/font><\/td>\s*<td VALIGN=TOP><font face=\"Arial\"><font size=-2>/, /.*(?=<\/font><\/font><\/td>\s*<\/tr>)/, rows[2])
      end

      if row[/Type of file/]
        typeOfFile = parseSimple(/Type of file:<\/font><\/font><\/td>\s*<td VALIGN=TOP><font face=\"Arial\"><font size=-2>/, /.*(?=<\/font><\/font><\/td>\s*<\/tr>)/, rows[3])
      end

      if row[/NUMERO CELEX/]
        numeroCelex = parseSimple(/'\)\">\s*<font face=\"Arial\"><font size=-2>/, /.*(?=<\/font><\/font>\s*<\/a>)/, rows[4])
      end
    }
    return documents, procedures, typeOfFile, numeroCelex
  end





  # removes whitespaces and HTML tags from a given string
  # maintains single word spacing blanks
  def clean(string)
    #remove HTML tags, if there are any
    string.gsub!(/<.+?>/, '') unless ((string =~ /<.+?>/) == nil)

    #convert &nbsp; into blanks
    string.gsub!(/&nbsp;/, ' ')

    #remove whitespaces
    string.gsub!(/\r/, '')
    string.gsub!(/\n/, '')
    string.gsub!(/\t/, '')

    #remove blanks at end
    string.strip!

    #convert multiple blanks into single blanks
    string.gsub!(/\ +/, ' ')

    return string
  end





  # fetches HTTP requests which use redirects
  def fetch(uri_str, limit = 10)
    # You should choose better exception.
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    response = Net::HTTP.get_response(URI.parse(uri_str))
    case response
    when Net::HTTPSuccess then response
    when Net::HTTPRedirection then fetch(response['location'], limit - 1)
    else
      response.error!
    end
  end





  # retrieves the law type's abbreviation
  def parseLawType
    # find out the law type
    begin
      type = @content[/<font face="Arial">\s*<font size=-1>(\d{4}\/)?\d{4}\/(AVC|COD|SYN|CNS)(?=<\/font>\s*<\/font>)/]
      type.gsub!(/<font face="Arial">\s*<font size=-1>(\d{4}\/)?\d{4}\//, '')
      raise if type.empty?
    rescue
      # this law does not have "type" data
      type = Configuration.missingEntry
    end
    return type
  end





  # since ruby 1.8.6 cannot handle positive look-behinds, the crawling is two-stepped

  #   a general method to extract pieces of a long string (simulating multilength look-behinds)
  #     extracts a substring out of a given string
  #     i.e.: result = string[/(?<=noise1)substring(?=noise2)/m]
  #
  #     where string is given
  #     noise1 is beforepattern
  #     substring and noise2 is behindpattern (should include the (?=...))
  #     returns result (the isolated substring)
  #
  #    to get the result, the following happens
  #    1. beforepattern + behindpattern is extracted from string, behindpattern may contain a lookahead and thus, this noise is not selected
  #    2. beforepattern is deleted
  #    3. since behindpattern consists of .* and some noise, which is not selected from the string, the remaining string is the result
  #
  #    beforepattern is a regexp object
  #    behindpattern is a regexp object
  #    string is a string
  def parseSimple beforePattern, behindPattern, string
    begin
      regexp = Regexp.new(beforePattern.source + behindPattern.source, Regexp::MULTILINE)
      result = string[regexp]
      result.gsub! Regexp.new(beforePattern.source, Regexp::MULTILINE), ''
      result = clean(result)
      raise if result.empty?
    rescue
      result = Configuration.missingEntry
    end
    return result
  end





  # parses the first table of the many piled up tables in the center of the page
  def processFirstBox table
    tableData = {}
    rows = table.split(/(?=<tr>)/)
    # remove the stuff before the first <tr>, immediately
    rows.shift

    # remove the first row, it is only the title and not of interest, here
    rows.shift


    # extract key and values, thus, iterate over each row, get the row entries
    rows.each { |row|
      # divide it in cells, but remove the junk before the first cell and also remove the first cell which is always empty
      cells = row.split(/<td/)[2..3]
      key = parseSimple(/VALIGN=TOP><font face="Arial"><font size=-2>/, /.*/, cells.first)

      value = Configuration.missingEntry

      # if the key is NUMERO CELEX or Documents, special measures have to be taken
      if key[/Documents:/]
        # there can be several documents, thus: split it
        documents = cells.last.split /<BR>/
        documents.pop # remove junk here
        documents.collect! { |document| parseSimple(/.*<font size=-2>/, /.*(?=<\/font><\/font>\s*(<\/a>)?)/, document)}
        documents = documents.join Configuration.innerSeparator
        value = documents
      elsif key[/NUMERO CELEX/]
        value = parseSimple(/'\)\">\s*<font face=\"Arial\"><font size=-2>/, /.*(?=<\/font><\/font>\s*<\/a>)/, cells.last)
      else
        value = parseSimple(/VALIGN=TOP>\s*<font face="Arial"><font size=-2>/, /.*/, cells.last)
      end
      tableData[key] = value
    }

    return tableData
  end
end