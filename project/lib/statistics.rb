# this is a file for debugging purposes
# it proviceds statistical analyses for the retrieved ids (not retrieving the actual contents)
# comment out, what you don't need



require "core"
Configuration.guiEnabled = false
Configuration.loglevel = Configuration::QUIET

lawIDs, lawIDsPerYear = Fetcher.retrieveLawIDs
puts "#{lawIDs.size} law IDs have been found, from which #{lawIDs.uniq.size} law IDs are unique"


# the histogram, counting for each ID the number of occurrences
histogram = {}
lawIDs.each {|i|
  if histogram.key? i then histogram[i] += 1
  else histogram[i] = 1
  end
}

# displaying the histogram for all laws with more than one occurrence
histogram.each_pair { |id, numberOfOccurrences|
    puts "duplicate at law #{id}, #{numberOfOccurrences} instances und"   if numberOfOccurrences > 1
}


# creating another hash that contains the set of years for each law that appears several times
duplicateLaws = {}
histogram.each_pair { |id, numberOfOccurrences|
  if numberOfOccurrences > 1
    duplicateLaws[id] = []  
    lawIDsPerYear.each_pair {|year, arrayOfIDsInThisYear|
      if arrayOfIDsInThisYear.member? id
        duplicateLaws[id] << year
      end
    }
  end
}

# displaying the ids which appear several times and the corresponding years in which they appear
duplicateLaws.each_pair { |id, arrayOfYears| 
  puts "#{id} appears in the years #{arrayOfYears.sort.join(', ')}"
}
