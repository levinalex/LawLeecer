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

require 'fetcher.rb'
require 'saver.rb'

class Core

  # Core is a singleton
  # this avoids having to provide the pointer to the core everywhere
  private_class_method :new
  @@singleton = nil

  def Core.createInstance
    @@singleton = new unless @@singleton
    @@singleton
  end





  # the main method, controlling the whole extraction process
  def startProcess

    Configuration.log_default "This is Law Leecher v#{Configuration::VERSION}"


    # this method returns also another hash array which is for debugging purposes, only
    # here, only the first array containing the law IDs is relevant
    lawIDs = Fetcher.retrieveLawIDs()


    # remove some duplicate IDs here
    lawIDs.sort!.uniq!


    @@numberOfLaws = lawIDs.size
    Core.createInstance.callback({'status' => "#{@@numberOfLaws} Gesetze gefunden"})
    Configuration.log_default "#{@@numberOfLaws} unique laws found"


    laws, timelineTitles, firstboxKeys = Fetcher.retrieveLawContents(lawIDs)


    @@numberOfResults = laws.size


    # sort the laws numerically
    laws = laws.sort_by {|law| law[Configuration::ID].to_i}


    Saver.save laws, timelineTitles, firstboxKeys


    Configuration.log_default 'Finished'
  end





  # callback to the gui and/or the terminal
  def callback bunchOfInformation
    GUI.createInstance.updateWidgets(bunchOfInformation) if Configuration.guiEnabled
  end





  # getter for the number of laws variable
  def numberOfLaws
    @@numberOfLaws
  end





  # getter for the number of results retrieved during retrieval
  def numberOfResults
    @@numberOfResults
  end
end