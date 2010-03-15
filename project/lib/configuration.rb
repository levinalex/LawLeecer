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
# WARRANTIES OF MERCHANTABILITY AND FITNESSs FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

class Configuration # and settings

  # year in which the crawling starts
  @@startYear = 1969
  def Configuration.startYear
    @@startYear
  end





  # to temporarily reduce the number of laws to crawl
  def Configuration.startYear= startYear
    @@startYear = startYear
  end





  # maximum hits per form submit (originally: 99, default: 20)
  NUMBER_OF_RESULTS_PER_PAGE = 1000000





  # csv file column separator
  COLUMN_SEPARATOR = '#'





  # inner separator, e.g. for documents
  INNER_SEPARATOR = ', '





  # the text which is put if a key has no value on the website
  MISSING_ENTRY = '[fehlt]'





  # categories to crawl
  def Configuration.fixedCategories
    [
      ID,
      TYPE,
      BLUEBOX_UPPERLEFTIDENTIFIER,
      BLUEBOX_UPPERCENTERIDENTIFIER,
      BLUEBOX_SHORTDESCRIPTION,
      GREENBOX_FIELDSOFACTIVITY,
      GREENBOX_LEGALBASIS,
      GREENBOX_PROCEDURES,
      GREENBOX_TYPEOFFILE,
      LASTBOX_DOCUMENTS,
      LASTBOX_PROCEDURES,
      LASTBOX_TYPEOFFILE,
      LASTBOX_NUMEROCELEX,
    ]
  end





  # constants for the result hashes
  TYPE = 'Type'
  BLUEBOX_UPPERLEFTIDENTIFIER = 'bluebox.UpperLeftIdentifier'
  BLUEBOX_UPPERCENTERIDENTIFIER = 'bluebox.UpperCenterIdentifier'
  BLUEBOX_SHORTDESCRIPTION = 'bluebox.ShortDescription'
  GREENBOX_FIELDSOFACTIVITY = 'greenbox.FieldsOfActivity'
  GREENBOX_LEGALBASIS = 'greenbox.LegalBasis'
  GREENBOX_PROCEDURES = 'greenbox.Procedures'
  GREENBOX_TYPEOFFILE = 'greenbox.TypeOfFile'
  TIMELINE = 'timeline'
  FIRSTBOX = 'firstbox'
  LASTBOX_DOCUMENTS = 'lastbox.Documents'
  LASTBOX_PROCEDURES = 'lastbox.Procedures'
  LASTBOX_TYPEOFFILE = 'lastbox.TypeOfFile'
  LASTBOX_NUMEROCELEX = 'lastbox.NumeroCelex'
  ID = 'ID'





  # filename of the export
  @@filename = "#{Dir.pwd}/export.csv"
  def Configuration.filename
    @@filename
  end
  def Configuration.filename= filename
    @@filename = filename
  end





  # version of the program
  VERSION = '1.4'






  # how much information to print on console
  # can be:
  # verbose
  VERBOSE = 2
  # default
  DEFAULT = 1
  # quiet
  QUIET = 0
  def Configuration.loglevel= level
    @@loglevel = level
  end





  # getter for the log level
  @@loglevel = DEFAULT
  def Configuration.loglevel
    @@loglevel
  end





  # print something when being verbose
  def Configuration.log_verbose message
    print "#{message}\n" if Configuration.loglevel >= VERBOSE
  end





  # print something when being verbose
  def Configuration.log_default message
    print "#{message}\n" if Configuration.loglevel >= DEFAULT
  end





  # number of parser threads to use
  @@numberOfParserThreads = 20
  def Configuration.numberOfParserThreads
    @@numberOfParserThreads
  end
  def Configuration.numberOfParserThreads= numberOfParserThreads
    @@numberOfParserThreads = numberOfParserThreads
  end





  # flag to overwrite the output file if it is existing already
  @@overwritePermission = false
  def Configuration.overwritePermission
    @@overwritePermission
  end
  def Configuration.overwritePermission= overwritePermission
    @@overwritePermission = overwritePermission
  end





  # flag whether or not to use the GUI
  @@guiEnabled = true
  def Configuration.guiEnabled
    @@guiEnabled
  end
  def Configuration.guiEnabled= guiEnabled
    @@guiEnabled = guiEnabled
  end
end