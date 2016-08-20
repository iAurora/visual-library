#!/bin/bash

# Source the configuration file
dir="${BASH_SOURCE%/*}"
if [[ ! -d "$dir" ]]; then dir="$PWD"; fi
. "$dir/vl-config.sh"

# Make sure all checks below are case-insensitive
shopt -s nocasematch


# Get the URL of the frontmost tab in Safari
pageURL="$(osascript -e 'tell application "Safari" to set pageURL to URL of front document')"

# Generate the timestamp
timeStamp=$(date '+%s')

# Set an empty custom title
customTitle=""

# Set the retina suffix
if $retinaMode; then
  retinaSuffix=" @2x"
else
  retinaSuffix=""
fi

# Set the default tag
macTags="untagged"


# Process the supplied options
while [ "$1" != "" ]; do
  case $1 in
    '@'* )  folderLabel="${1#@}"
            ;;

    '+'* )  macTags="${1#+}"
            ;;

    -t )    shift
            customTitle="$1 "
            ;;
            
    * )     osascript -e 'display notification "One or more of the provided options doesn'"'"'t look right. Using the defaults instead." with title "Ooops!"'
  esac
  shift
done


# Call the "label > subdir" mapping function from the config
setDestinationDir

# Compose the filename without the extension
fileName="${customTitle}${timeStamp}${retinaSuffix}"

# Compose the destination directory for the file
subDirPath=$rootDir$subDir

# Compose the path for the page subdir
responsiveDirPath="${subDirPath}${fileName/$retinaSuffix/}/"

# Create the subdir to contain the screenshots of the page
mkdir "$responsiveDirPath"


# Create screenshots for all responsive widths
for w in "${responsiveWidths[@]}"
do

  # Take the primary screenshot of the page
  /usr/local/bin/webkit2png "${pageURL}" --ignore-ssl-check --scale=1 -F --width="$w" --clipwidth="$w" -D "${responsiveDirPath}" -o "${fileName}"

  # Check the success status
  if [[ $? -eq 1 ]]; then
    osascript -e 'delay "0.5"' -e 'display notification "Can'"'"'t take a screenshot of this page. Check the README doc on GitHub for a possible fix." with title "Failure!"'
   exit 1
  fi

  # Compose the path to the file and trim the suffix that webkit2png adds automatically
  filePathWithSuffix="${responsiveDirPath}${fileName}-full.png"

  filePath="${filePathWithSuffix/$retinaSuffix-full/ $w$retinaSuffix}"

  mv "$filePathWithSuffix" "$filePath"


  # Optimize the image
  if $optimiseImages; then 

    optimisationError () { 
      osascript -e 'delay "0.5"' -e 'display notification "Something went wrong" with title "Optimisation failed"' 
    }

    optimisePNG

  fi


  # Apply macOS tags to the file
  /usr/local/bin/tag -a "${macTags}" "${filePath}" || osascript -e 'delay "0.5"' -e 'display notification "Something went wrong" with title "Tagging failed"'

  # Get the title of the frontmost tab of Safari
  pageTitle="$(osascript -e 'tell application "Safari" to set pageTitle to name of front document')"

  # Compose the Finder Comments
  finderComments="title: ${pageTitle}"$'\n\n'"page: ${pageURL}"

  # Apply the Finder Comments
  osascript -e 'on run {f, c}' -e 'tell app "Finder" to set comment of (POSIX file f as alias) to c' -e end "${filePath}" "${finderComments}"

done


# Grab the width of the primary screenshot
primaryWidth="${responsiveWidths[0]}"

# Compose the path to the primary screenshot within the page subfolder
primaryFileInner="${responsiveDirPath}${fileName/$retinaSuffix/ $primaryWidth$retinaSuffix}.png"

# Compose the path to the primary screenshot outside of the page subfolder
primaryFileOuter="${subDirPath}${fileName/$retinaSuffix/ $primaryWidth$retinaSuffix}.png"

# Move the primary screenshot to the directory specified by the label
mv "$primaryFileInner" "$primaryFileOuter"

# Create the symbolic link for the moved file in the page subfolder
ln -s "$primaryFileOuter" "$primaryFileInner"


# Confirm success
osascript -e 'delay "1"' -e 'display notification "All went well. Hopefully." with title "Job complete!"'