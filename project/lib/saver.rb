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

require 'iconv'

class Saver

  # converts a string from UTF8 to ANSI
  def Saver.convertUTF8ToANSI string, law
    begin
      Iconv.new('iso-8859-1', 'utf-8').iconv(string)
    rescue Iconv::IllegalSequence => is
      puts "law ##{law}: Unicode character conversion error: #{is.message}"
      puts "Writing it inconverted"
      return string
    end
  end





  # saves the results into a file
  def Saver.save laws, timelineTitles, firstboxKeys
    Core.createInstance.callback({'status' => "Speichere in #{Configuration.filename}..."})


    # to see all conversation errors, uncomment the following line
    # laws.each { |law| convertUTF8ToANSI(law.inspect, law[Configuration::ID])}

    begin
      file = File.new(Configuration.filename, 'w')

      # basically, two things are done here:
      # first, the title line is composed of several array (fixed parts, variable ones)
      # second, a really big table is created where all laws and all their information are stored
      # each row is a hash
      # this table is then serialized in the file
      # one table row contains one law, basically flattening its contents
      reallyBigTable = []


      # first, write all categories which are always available (but might be empty)
      headerRow = []
      Configuration.fixedCategories.each {|category| headerRow << category}


      # second, add all the firstboxKeys
      firstboxKeys.each { |key| headerRow << 'firstbox.' + key}


      # third, add all the timelineTitles (each twice, one with date, another with decision)
      timelineTitles.each { |title|
        headerRow << title + '.date'
        headerRow << title + '.decision'
      }



      # write data in file

      # now, create a line in this really big table for each law
      laws.each { |law|

        # the row, which will be successively filled
        row = {}

        # first, save fixed category data, since it is reliably present at all laws (but maybe with empty strings)
        Configuration.fixedCategories.each { |category|

          # category contains the current key like "legal basis" or "primarily responsible"
          row[category] = law[category]
        }


        # second, save all timeline data
        law['timeline'].each { |step|
          row[step['titleOfStep'] + '.date'] = step['timestamp']
          row[step['titleOfStep'] + '.decision'] = step['decision']
        }

        # third, save all firstbox data
        firstboxKeys.each { |key|
          row['firstbox.' + key] = law[Configuration::FIRSTBOX][key]
        }

        reallyBigTable << row
      }




      # now, write everything to file
      # first: the header row
      file.puts convertUTF8ToANSI(headerRow.join(Configuration.columnSeparator), 'header row')


      # second: all the rest (data rows)
      reallyBigTable.each { |row|
        line = []
        headerRow.each { |key|
          line << row[key]
        }
        line = line.join Configuration.columnSeparator
        convertedLine = convertUTF8ToANSI(line, row[Configuration::ID])
        file.puts convertedLine
      }

      file.close
    end

  rescue Exception => ex
    puts "Exception: #{ex}"
    Core.createInstance.callback({'status' => "Datei #{Configuration.filename} konnte nicht geöffnet werden. Wird sie von einem anderen Programm benutzt?"})
  end
end