#!/bin/sh
echo 'Welche Version von Law Leecher ist gerade aktuell? (z.B. "1.4")'
read version
programmname="Law Leecher $version"
echo "Der Programmname ist \"$programmname\"."

if [ -d "$programmname" ];
then
  echo "Ein Verzeichnis mit dem Namen \"$programmname\" existiert bereits. Es muss erst gelöscht werden."
  exit
else
  mkdir "$programmname"
fi

echo 'Kopiere das Programm...'
svn export -q "Law Leecher/lib" "$programmname/Programm"

echo 'Kopiere die Dokumentationsquellen...'
mkdir "$programmname/Dokumentation"
svn export -q "Dokumentation, Links und PDFs/doku" "$programmname/Dokumentation/src"

echo 'Kopiere die Dokumentation...'
mv "$programmname/Dokumentation/src/Documentation.pdf" "$programmname/Dokumentation/"

echo 'Wandle Verzeichnis in Archiv um...'
zip -m -9 -r -T -q "$programmname.zip" "$programmname"

echo 'Fertig!'
