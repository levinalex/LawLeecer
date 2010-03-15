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
require 'net/http'
require 'set'
require 'configuration.rb'
require 'date/format'
require 'monitor'
require 'parser_thread.rb'

class Fetcher

  # gets all the law IDs in the whole database
  def Fetcher.retrieveLawIDs
    # array containing all law ids
    lawIDs = []

    Core.createInstance.callback({'status' => 'Frage alle Gesetze an. Das kann durchaus mal zwei Minuten oder mehr dauern.'})
    Configuration.log_default "Listing all available laws for the specified time range..."

    # retrieve all laws separately by year
    # this makes it possible to retrieve only laws starting with a given year
    # furthermore, sometimes it does not work to get all law ids listed on one single page
    (Configuration.startYear..Time.now.year).each { |year|

      http = Net::HTTP.start('ec.europa.eu')

      # we will retrieve a huge HTML file, which might take longer
      http.read_timeout = 300
      http.open_timeout = 300

      Core.createInstance.callback({'status' => "Suche Gesetze für das Jahr #{year}..."})
      Configuration.log_verbose "Listing laws for year #{year}..."
      response = http.post('/prelex/liste_resultats.cfm?CL=en', "doc_typ=&docdos=dos&requete_id=0&clef1=&doc_ann=&doc_num=&doc_ext=&clef4=&clef2=#{year}&clef3=&LNG_TITRE=EN&titre=&titre_boolean=&EVT1=&GROUPE1=&EVT1_DD_1=&EVT1_MM_1=&EVT1_YY_1=&EVT1_DD_2=&EVT1_MM_2=&EVT1_YY_2=&event_boolean=+and+&EVT2=&GROUPE2=&EVT2_DD_1=&EVT2_MM_1=&EVT2_YY_1=&EVT2_DD_2=&EVT2_MM_2=&EVT2_YY_2=&EVT3=&GROUPE3=&EVT3_DD_1=&EVT3_MM_1=&EVT3_YY_1=&EVT3_DD_2=&EVT3_MM_2=&EVT3_YY_2=&TYPE_DOSSIER=&NUM_CELEX_TYPE=&NUM_CELEX_YEAR=&NUM_CELEX_NUM=&BASE_JUR=&DOMAINE1=&domain_boolean=+and+&DOMAINE2=&COLLECT1=&COLLECT1_ROLE=&collect_boolean=+and+&COLLECT2=&COLLECT2_ROLE=&PERSON1=&PERSON1_ROLE=&person_boolean=+and+&PERSON2=&PERSON2_ROLE=&nbr_element=#{Configuration::NUMBER_OF_RESULTS_PER_PAGE}&first_element=1&type_affichage=1")
      content = response.body


      # check, whether all hits are on the page or that pagination is used, instead
      # there are two ways to check it, we use both for safety reasons

      if content[/The document is not available in PreLex./]
        Configuration.log_verbose('There are no laws on this page.')
        next
      end

      lastEntryOnPage = content[/\d{1,5}\/\d{1,5}(?=<\/div>\s*<\/TD>\s*<\/TR>\s*<TR bgcolor=\"#(ffffcc|ffffff)\">\s*<TD colspan=\"2\" VALIGN=\"top\" align=\"left\">\s*<FONT CLASS=\"texte\">.*<\/FONT>\s*<\/TD>\s*<\/TR>\s*<\/table>\s*<\/td>\s*<\/tr>\s*<tr>\s*<td align=\"center\">\s*<TABLE border=0 cellpadding=0 cellspacing=0>\s*<tr align=\"center\">\s*<\/tr>\s*<\/table>\s*<\/td>\s*<\/tr>\s*<\/table>\s*<!-- BOTTOM NAVIGATION BAR)/]
      lastEntry, maxEntries = lastEntryOnPage.split('/')

      # first, compare the last number with the max number (e.g., 46/2110)
      # if it's equal, all hits are on this page, which is good, otherwise: bad
      if lastEntry != maxEntries
        raise 'Not all laws on page. (last entry != number of entries)'
      end

      # second, the pagination buttons must not be present (at least no "page 2" button)
      unless content[/<td align="center"><font size="-2" face="arial, helvetica">2<\/font><br\/>/].nil?
        raise 'There are pagination buttons, not all laws would be retrieved.'
      end


      #fetch out ids for each single law as array and append it to the current set of ids
      #the uniq! removes double ids (<a href="id">id</a>)
      additionalLawIDs = content.scan(/\d{1,6}(?=" title="Click here to reach the detail page of this file">)/)
      additionalLawIDs.uniq! # to eliminate the twin of each law id (which is inevitably included)

      lawIDs.concat additionalLawIDs
    }
    Configuration.log_default "#{lawIDs.size} laws found"
    return lawIDs
  end





  # retrieves the details for each law by startin threads for each law
  def Fetcher.retrieveLawContents lawIDs
    Configuration.log_default "Starting to retrieve details for each law"

    #      #####        #####        #####
    #      #   #        #   #        #   #
    #      #   #        #   #        #   #
    #      #   #        #   #        #   #
    #    ###   ###    ###   ###    ###   ###
    #     #     #      #     #      #     #
    #      #   #        #   #        #   #
    #       # #          # #          # #
    #        #            #            #
    ######################################################
    # interesting debug position
    #
    # set this array to something different (e.g., some special law ids you want
    # to examine) to debug
    #
    # examples (one of):
    # lawIDs = [197729, 154298, 154182]
    # lawIDs = [154182]
    # lawIDs = [197729]
    #######################################################
    # lawIDs = [something]


    #lawIDs = [11260, 11262, 11263, 11264, 11265, 11266, 11267, 11268, 11269, 11270, 11271, 11272, 11273, 11274, 11275, 11276, 11277, 11278, 11279, 11280, 11281, 11282, 11283, 11284, 11285, 11286, 11287, 11288, 11289, 11290, 11291, 11292, 11293, 11294, 11295, 11296, 11297, 11298, 11299, 11300, 11301, 11302, 11303, 11304, 11305, 11306, 11307, 11308, 11309, 11310, 11311, 11312, 11313, 11314, 11315, 11316, 11317, 11318, 11319, 11320, 11321, 11322, 11323, 11324, 11325, 11326, 11327, 11328, 11329, 11330, 11331, 11332, 11333, 11334, 11335, 11336, 11337, 11338, 11339, 11340, 11341, 11342, 11343, 11344, 11345, 11346, 11347, 11348, 11349, 11350, 11351, 11352, 11353, 11354, 11355, 11356, 11357, 11358, 11359, 11360, 11361, 11362, 11363, 11364, 11365, 11366, 11367, 11368, 11369, 11370, 11371, 11372, 11373, 11374, 11375, 11376, 11377, 11378, 11379, 11380, 11381, 11382, 11383, 11384, 11385, 11386, 11387, 11388, 11389, 11390, 11391, 11392, 11393, 11394, 11395, 11396, 11397, 11398, 11399, 11400, 11401, 11402, 11403, 11404, 11405, 11406, 11407, 11408, 11409, 11410, 11411, 11412, 11413, 11414, 11415, 11416, 11417, 11418, 11419, 11420, 11421, 11422, 11423, 11424, 11425, 11426, 11427, 11428, 11429, 11430, 11431, 11432, 11433, 11434, 11435, 11436, 11437, 11438, 11439, 11440, 11441, 11442, 11443, 11444, 11445, 11446, 11447, 11448, 11449, 11450, 11451, 11452, 11453, 11454, 11455, 11456, 11457, 11458, 11459, 11460, 11461, 11462, 11463, 11464, 11465, 11466, 11467, 11468, 11469, 11470, 11471, 11472, 11473, 11474, 11475, 11476, 11477, 11478, 11479, 11480, 11481, 11482, 11483, 11484, 11485, 11486, 11487, 11488, 11489, 11490, 11491, 11492, 11494, 11495, 11496, 11497, 11498, 11499, 11500, 11501, 11502, 11503, 11504, 11505, 11506]

    # total number of laws to retrieve
    overalNumberOfLaws = lawIDs.size

    # contribution of each law to the progess bar
    # is irrelevant when not in GUI mode
    progressBarIncrement = 1.0 / overalNumberOfLaws


    # the array in which the threads (references) are stored
    threads = []



    numberOfEmptyLaws = 0
    numberOfDatabaseErrorLaws = 0
    numberOfUnexpectedErrorLaws = 0
    numberOfCorrectlyRetrievedLaws = 0
    numberOfOtherLaws = 0


    globalLawIDs = lawIDs.clone
    globalResults = []

    # inner law id storage
    localLawIDs = globalLawIDs.clone

    # some laws will got lost, thus the whole retrieval process is repeated, until
    # there is a result for each law (positive or negative)
    begin

      # array containing all law information of this run
      localResults = []

      # start new threads as long as there is still work to do
      # if there is no work to do (law ids are empty), still repeat and
      # retrieve the results of the threads
      while !localLawIDs.empty? or !threads.empty?

        # iterate over the list of threads and remove those, who have finished
        threads.map! { |thread|
          if !thread.alive?
            # if thread is finished (= !alive), save the result and replace this thread entry with nil (to delete it with the compact! below)
            threadResult = thread.value
            localResults << threadResult
            nil # replace the current entry in the threads array with nil (thus, it will be purged, below)
          else
            # if the thread has not finished yet, replace the entry with itself (no change)
            thread
          end
        }.compact! # purge the array, removing all nil entries, i.e. tidy up and create free slots for new threads


        # start new threads if there are free slots and there is some work
        if (threads.size < Configuration.numberOfParserThreads and !localLawIDs.empty?)
          # start a new thread
          theLawToProcess = localLawIDs.shift

          Configuration.log_default "#{localLawIDs.size} laws left" if (localLawIDs.size % 1000 == 0 and localLawIDs.size > 0)

          threads << Thread.new {
            parserThread = ParserThread.new
            parserThread.retrieveAndParseALaw theLawToProcess
          }

          #progressBarIncrement = erledigt/alle = result.size +  aktuell schon abgefeuerte /  alle
          #p progressBarIncrement = (globalResults.size + localResults.size) / overalNumberOfLaws.size.to_f

          #progressBarIncrement = 0.23

          Core.createInstance.callback({
              'progressBarIncrement' => progressBarIncrement,
              'status' => "#{overalNumberOfLaws - localLawIDs.size}/#{overalNumberOfLaws} Gesetze verarbeitet"#,
              # 'progressBarText' => "#{(overalNumberOfLaws - lawIDs.size) * 100 / overalNumberOfLaws} %"
            }
          )
        else
          # do not create a new thread now, instead wait a bit
          sleep 0.1
        end
      end


      # some laws may appear several times (instead of some other laws, which
      # are now missing and have to be retrieved in the next run)
      localResults = removeDuplicates(localResults)



      # alle ids für den nächsten durchlauf löschen, die irgendwie zurückgekommen sind (z.b. als fehler oder als korrektes gesetz)
      localResults.each { |result|
        if result.class == Hash
          if result.key? "error" and result["error"] == ParserThread::POSSIBLY_RECOVERABLE_ERROR
            # do nothing, i.e. this law will be retrieved in the next run
            Configuration.log_default "Law ##{result[Configuration::ID]} caused a recoverable error and will be repeated."
            Core.createInstance.callback({
                'progressBarIncrement' => -progressBarIncrement
              })
          else
            globalLawIDs.delete result[Configuration::ID]
            globalResults << result
          end
        end
      }



      localLawIDs = globalLawIDs.clone
    end while localLawIDs.size > 0

    # for safety
    localLawIDs = nil
    localResults = nil


    # create statistics
    globalResults.each { |result|
      if result.class != Hash
        $stderr.puts "A result has not been a Hash and will be removed from the set of results."
        globalResults.delete result
      elsif result.key? "error"
        case result["error"]
        when ParserThread::EMPTY_LAW_ERROR then numberOfEmptyLaws += 1
        when ParserThread::DATABASE_ERROR then numberOfDatabaseErrorLaws += 1
        when ParserThread::UNEXPECTED_ERROR then numberOfUnexpectedErrorLaws += 1
        end
      elsif result.key? Configuration::TYPE # this is the check, whether this result item is a correctly parsed law
        numberOfCorrectlyRetrievedLaws += 1
      else
        numberOfOtherLaws += 1
      end
    }



    Configuration.log_default "#{Core.createInstance.numberOfLaws} laws were to be retrieved"
    Configuration.log_default "-----------------------------------------------"
    Configuration.log_default "#{numberOfEmptyLaws} laws were empty"
    Configuration.log_default "#{numberOfDatabaseErrorLaws} laws had a database error"
    Configuration.log_default "#{numberOfUnexpectedErrorLaws} laws had an \"unexpected\" error"
    Configuration.log_default "#{numberOfOtherLaws} laws could not be retrieved for other reasons"
    Configuration.log_default "#{numberOfCorrectlyRetrievedLaws} laws have been retrieved successfully"
    Configuration.log_default "-----------------------------------------------"
    Configuration.log_default "Sum: #{numberOfEmptyLaws + numberOfDatabaseErrorLaws + numberOfUnexpectedErrorLaws + numberOfCorrectlyRetrievedLaws + numberOfOtherLaws} laws in total"


    # remove all remaining empty laws by only selecting those items that are hashes containing the type key (i.e., are expected to be real laws)
    globalResults = globalResults.select {|law| law.class == Hash and law.key? Configuration::TYPE}

    # extract the keys of the timeline hash in all of the crawled laws (used for creating the header line in the export file)r
    timelineKeys = extractTimelineKeysFromCrawledLaws globalResults

    # extract the keys of the first box hash in all of the crawled laws (used for creating the header line in the export file)r
    firstboxKeys = extractfirstboxKeysFromCrawledLaws globalResults

    return globalResults, timelineKeys, firstboxKeys
  end





  private

  # finds out all timeline keys (e.g. "Adoption by Commission", "EP Opinion 2nd reading")
  # these are used for the header line of the export file
  # some can occur several times, thus they have to be made unique, e.g. "Adoption by Commission001", "Adoption by Commission002"
  # input are laws, which are hashes with a key named "timeline", this entry is an array of hashes
  # each of these hashes has three entries of which one is named titleOfStep
  # this is the string of relevance, here, called the "timeline key"
  def Fetcher.extractTimelineKeysFromCrawledLaws results
    timelineKeys = []

    # go through each law and examine the set of keys in the timeline array
    # while iterating through each law, rename the titleOfStep-values to
    # "abc001" or "abc002"... if they already exist for this law
    # e.g. timeline = [{"titleOfStep" => "abc"}, {"titleOfStep" => "xxx", {"titleOfStep" => "abc"}]
    # this results in
    # timeline = [{"titleOfStep" => "abc001"}, {"titleOfStep" => "xxx001", {"titleOfStep" => "abc002"}]
    #
    # at the same time, a list of all the values has also to be tracked, e.g. ["abc001", "xxx001", "abc002"]

    results.each { |law|

      # this is the temporary storage of timelineKey names ("abc001", ...)
      timelineKeysUsedInThisLaw = []
      timeline = law[Configuration::TIMELINE]

      timeline.each { |step|
        # extract the step's title and introduce the enummeration
        stepTitle = step['titleOfStep'] + '001'

        # this number (001) might have been in use already, if the title did appear before
        # thus, possibly find the next free index, e.g. 002, 003, 004...
        while timelineKeysUsedInThisLaw.member? stepTitle
          stepTitle.next!
        end

        # now, stepTitle has an index which is unique for this law (because of the law-overall timelineKeysUsedInThisLaw-array)
        # it is saved with the current index and also saved in the array (for that it is being found for later step titles)
        step['titleOfStep'] = stepTitle
        timelineKeysUsedInThisLaw << stepTitle
      } # end of this step

      # save the changed timeline back into the law
      law[Configuration::TIMELINE] = timeline

      # save the used timeline titles in the global list, so that the export file header can make display it
      timelineKeys.concat timelineKeysUsedInThisLaw
      timelineKeys.uniq!
    } # end of this law

    timelineKeys.sort!

    return timelineKeys
  end





  # finds out all keys of the firstbox (e.g. "Mandatory consultation", "Responsible")
  # these are used for the header line of the export file
  # it is unclear, which ones can occur
  # input are laws, which are hashes with a key named "firstbox", this entry is an array of hashes
  # each of these hashes has only one entry, the key mapped to the value
  def Fetcher.extractfirstboxKeysFromCrawledLaws results
    firstboxKeys = []

    # go through each law and examine the set of keys in the timeline array
    # while iterating through each law, rename the titleOfStep-values to
    # "abc001" or "abc002"... if they already exist for this law
    # e.g. timeline = [{"titleOfStep" => "abc"}, {"titleOfStep" => "xxx", {"titleOfStep" => "abc"}]
    # this results in
    # timeline = [{"titleOfStep" => "abc001"}, {"titleOfStep" => "xxx001", {"titleOfStep" => "abc002"}]
    #
    # at the same time, a list of all the values has also to be tracked, e.g. ["abc001", "xxx001", "abc002"]

    results.each { |law|

      # this is the temporary storage of timelineKey names ("abc001", ...)
      firstboxHash = law[Configuration::FIRSTBOX]
      # save the used timeline titles in the global list, so that the export file header can display it
      firstboxKeys.concat firstboxHash.keys
      firstboxKeys.uniq!
    } # end of this law

    firstboxKeys.sort!
    return firstboxKeys
  end



  # removes exact duplicates (about 1% of the whole data comes from duplicate entries)
  # actually, it removes all entries with the same id regardless of the actual attributes
  # however, all inspected duplicate tuples have been exact duplicates, thus the check for identic ids is safe enough
  def Fetcher.removeDuplicates laws
    alreadyFoundLawIDs = []
    laws.delete_if { |law|
      id = law[Configuration::ID]
      if alreadyFoundLawIDs.include? id
        true
      else
        alreadyFoundLawIDs << id
        false
      end
    }
    return laws
  end

end