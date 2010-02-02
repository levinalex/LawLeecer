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
    #array containing all law ids
    lawIDs = []

    Core.createInstance.callback({'status' => 'Frage alle Gesetze an. Das kann durchaus mal zwei Minuten oder mehr dauern.'})
    Configuration.log_default "Listing all available laws for the specified time range..."

    # retrieve all laws separately by year
    (Configuration.startYear..Time.now.year).each { |year|

      http = Net::HTTP.start('ec.europa.eu')

      # we will retrieve a huge HTML file, which might take longer
      http.read_timeout = 300
      http.open_timeout = 300

      Core.createInstance.callback({'status' => "Suche Gesetze für das Jahr #{year}..."})
      Configuration.log_verbose "Listing laws for year #{year}..."
      response = http.post('/prelex/liste_resultats.cfm?CL=en', "doc_typ=&docdos=dos&requete_id=0&clef1=&doc_ann=&doc_num=&doc_ext=&clef4=&clef2=#{year}&clef3=&LNG_TITRE=EN&titre=&titre_boolean=&EVT1=&GROUPE1=&EVT1_DD_1=&EVT1_MM_1=&EVT1_YY_1=&EVT1_DD_2=&EVT1_MM_2=&EVT1_YY_2=&event_boolean=+and+&EVT2=&GROUPE2=&EVT2_DD_1=&EVT2_MM_1=&EVT2_YY_1=&EVT2_DD_2=&EVT2_MM_2=&EVT2_YY_2=&EVT3=&GROUPE3=&EVT3_DD_1=&EVT3_MM_1=&EVT3_YY_1=&EVT3_DD_2=&EVT3_MM_2=&EVT3_YY_2=&TYPE_DOSSIER=&NUM_CELEX_TYPE=&NUM_CELEX_YEAR=&NUM_CELEX_NUM=&BASE_JUR=&DOMAINE1=&domain_boolean=+and+&DOMAINE2=&COLLECT1=&COLLECT1_ROLE=&collect_boolean=+and+&COLLECT2=&COLLECT2_ROLE=&PERSON1=&PERSON1_ROLE=&person_boolean=+and+&PERSON2=&PERSON2_ROLE=&nbr_element=#{Configuration.numberOfMaxHitsPerPage.to_s}&first_element=1&type_affichage=1")
      content = response.body


      # check, whether all hits are on the page
      # there are two ways to check it, we use both for safety reasons

      if content[/The document is not available in PreLex./]
        Configuration.log_verbose('There are no laws on this page.')
        next
      end

      lastEntryOnPage = content[/\d{1,5}\/\d{1,5}(?=<\/div>\s*<\/TD>\s*<\/TR>\s*<TR bgcolor=\"#(ffffcc|ffffff)\">\s*<TD colspan=\"2\" VALIGN=\"top\">\s*<FONT CLASS=\"texte\">.*<\/FONT>\s*<\/TD>\s*<\/TR>\s*<\/table>\s*<center>\s*<TABLE border=0 cellpadding=0 cellspacing=0>\s*<tr align=\"center\">\s*<\/tr>\s*<\/table>\s*<\/center>\s*<!-- BOTTOM NAVIGATION BAR)/]
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
    Core.createInstance.callback({'status' => "#{lawIDs.size} Gesetze gefunden"})
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

    # total number of laws to retrieve
    overalNumberOfLaws = lawIDs.size

    # contribution of each law to the progess bar
    # is irrelevant when not in GUI mode
    progressBarIncrement = 1.0 / overalNumberOfLaws

    # array containing all law information
    results = []

    # the array in which the threads (references) are stored
    threads = []

    while !lawIDs.empty?
      # iterate over the list of threads and remove those, who have finished
      threads.map! { |thread|
        if !thread.alive?
          # if thread is finished (= !alive), save the result and replace this thread entry with nil (to delete it with the compact! below)
          threadResult = thread.value
          results << threadResult unless threadResult.nil?
          nil
        else
          # if the thread has not finished yet, replace the entry with itself (no change)
          thread
        end
      }.compact!

      if (threads.size < Configuration.numberOfParserThreads)
        # start a new thread
        theLawToProcess = lawIDs.shift

      	Configuration.log_default "#{lawIDs.size} laws left" if (lawIDs.size % 100 == 0 and lawIDs.size > 0)

        threads << Thread.new {
          parserThread = ParserThread.new
          parserThread.retrieveAndParseALaw theLawToProcess
        }
        Core.createInstance.callback({'progressBarIncrement' => progressBarIncrement, 'status' => "#{overalNumberOfLaws - lawIDs.size}/#{overalNumberOfLaws} Gesetze verarbeitet", 'progressBarText' => "#{(overalNumberOfLaws - lawIDs.size) * 100 / overalNumberOfLaws} %"})
      else
        # do not create a new thread now, instead wait a bit
        sleep 0.1
      end
    end


    # catch all remaining threads here
    Configuration.log_default "No more laws left, waiting for threads to finish."
    threads.each {|thread|
      threadResult = thread.value
      results << threadResult unless threadResult.nil?
    }

    # remove all remaining empty laws which are represented as Fixnums rather
    # than being hashes with all the parsed information
    results = results.select {|law| law.class != Fixnum or law.class != String}

    # extract the keys of the timeline hash in all of the crawled laws (used for creating the header line in the export file)r
    timelineKeys = extractTimelineKeysFromCrawledLaws results

    # extract the keys of the first box hash in all of the crawled laws (used for creating the header line in the export file)r
    firstboxKeys = extractfirstboxKeysFromCrawledLaws results

    return results, timelineKeys, firstboxKeys
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
end
