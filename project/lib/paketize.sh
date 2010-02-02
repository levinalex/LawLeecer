#! /bin/sh

echo "Which version shall the archive have in its name? (e.g., \"1.2.3\" for lawleecher-1.2.3.zip): "
read version
packagefile=lawleecher-$version.zip

if [ -f $packagefile ]; then
  echo "\"$packagefile\" already exists. Please delete it first."
  exit 1
fi

cp ../../documentation/tex/Documentation.pdf .
zip --quiet $packagefile configuration.rb core.rb fetcher.rb g_u_i.rb main.rb parser_thread.rb saver.rb Documentation.pdf start.bat
rm Documentation.pdf
 
echo "\"$packagefile\" has been created successfully."
