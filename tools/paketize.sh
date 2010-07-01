#! /bin/sh

echo "Which version shall the archive have in its name? (e.g., \"1.2.3\" for lawleecher-1.2.3.zip): "
read version
packagefile=lawleecher-$version.zip

if [ -f $packagefile ]; then
  echo "\"$packagefile\" already exists. Please delete it first."
  exit 1
fi

tempdir=tempdir
if [ -d $tempdir ]; then
  echo "The temporary directory \"$tempdir\" already exists. Remove it or change this script."
  exit 1
fi

mkdir $tempdir
cd $tempdir

cp ../../documentation/tex/Documentation.pdf .

srcdir=../../project/lib
cp $srcdir/configuration.rb $srcdir/core.rb $srcdir/fetcher.rb $srcdir/g_u_i.rb $srcdir/main.rb $srcdir/parser_thread.rb $srcdir/saver.rb $srcdir/start.bat .

zip -q ../$packagefile configuration.rb core.rb fetcher.rb g_u_i.rb main.rb parser_thread.rb saver.rb Documentation.pdf start.bat

cd ..
rm -r $tempdir
 
echo "\"$packagefile\" has been created successfully."
