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
  def Saver.convertUTF8ToANSI string, lawID
    begin
      # first: try it the easy way
      return Iconv.new('iso-8859-1', 'utf-8').iconv(string)
    rescue
      # obviously, the character did not fit into iso 8859-1 (latin 1)
      out = []
      bytes = string.bytes.to_a
      while (!bytes.empty?) do
        b = bytes.shift
        if b <= 127
          out << b
        else
          # b is non-ascii character and here: beginning of UTF-8 multibyte character
          # find out, how many bytes are involved (2, 3, or 4, since it is a multibyte character)
          # 2-byte character 110xxxxx => 11000000-11011111 (192-223)
          # 3-byte character 1110xxxx => 11100000-11101111 (224-239)
          # 4-byte character 11110xxx => 11110000-11110111 (340-247)

          readXMoreBytes = 0
          case b
          when 192..223 then readXMoreBytes = 1
          when 224..239 then readXMoreBytes = 2 # proper 3-byte characters will never fit into ANSI
          when 240..247 then readXMoreBytes = 3 # proper 4-byte characters will never fit into ANSI
          else raise "The encoding is damaged for law #{lawID}, there are no 5-or-more-byte characters in UTF-8. Unpredictable behaviour ahead..."
          end

          multibyte = [b]
          # no matter whether it will fit into ANSI, it has to be consumed from the array
          begin
            multibyte.concat bytes.shift readXMoreBytes
          rescue
            $stderr.puts "#{lawID}: an incomplete multi-byte UTF-8 character stream has been detected, something went wrong..."
            return string
          end


          # 3 or 4-byte characters cannot be converted and are ignored (but are removed from the source array)
          if multibyte.size > 2
            next
          end

          # the maximum ANSI character 11111111 (255) is UTF-8 11000011 10111111 (195 191)
          # if the first byte of multibyte is <= 195, and the second byte is <= 191, and the interpreter is executing these lines
          # then it should be possible to convert it into ANSI and therefore it is considered

          if multibyte[0] <= 195 and multibyte[1] <= 191 then
            out.concat multibyte
          end
        end
      end # the whole byte array has been gone through

      # now, the array containing only "safe" bytes can be re-converted to a string and then converted into ANSI again
      string = ''
      out.each {|byte| string << byte}
      return Iconv.new('iso-8859-1', 'utf-8').iconv(string)
    end
  end





  # saves the results into a file
  def Saver.save laws, timelineTitles, firstboxKeys
    Core.createInstance.callback({'status' => "Speichere in #{Configuration.filename}..."})
    Configuration.log_verbose "Saving to #{Configuration.filename}"

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
    $stderr.puts "Exception: #{ex}"
    Core.createInstance.callback({'status' => "Datei #{Configuration.filename} konnte nicht geöffnet werden. Wird sie von einem anderen Programm benutzt?"})
    Configuration.log_default "File #{Configuration.filename} could not be opened, is it already open? Exiting."
  end
end