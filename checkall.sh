#!/bin/bash

# Let's check if we have a token properly set
if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "The GITHUB_TOKEN is required."
	exit 1
fi


# Some prerequisites
curl -JLO https://raw.githubusercontent.com/Sarcasm/run-clang-format/master/run-clang-format.py
chmod +x ./run-clang-format.py

# Now let's get the modified files
echo "Event path: $GITHUB_EVENT_PATH"
FILES_LINK=`jq -r '.pull_request._links.self.href' "$GITHUB_EVENT_PATH"`/files
echo "Files = $FILES_LINK"
curl -H "Authorization: token $GITHUB_TOKEN" $FILES_LINK > files.json
FILES_URLS_STRING=`jq -r '.[].contents_url' files.json`

readarray -t URLS <<<"$FILES_URLS_STRING"

mkdir files
cd files
for i in "${URLS[@]}"
do
	echo "Downloading $i"
	FILENAME=`basename ${i%%\?*}`
	curl -H "Authorization: token $GITHUB_TOKEN" --header "Accept: application/vnd.github.v3.raw" --header "User-Agent: ${OWNER}/${REPO} (curl v7.47.0)" -L -o $FILENAME $i
done

echo "Files downloaded!"
ls -la
cd ..

echo "Performing checkup:"
# We can't use clang-tidy without checking out the whole repo, or adding a compilation database, so skipping for now
#clang-tidy --version
#clang-tidy *.cpp -checks=boost-*,bugprone-*,performance-*,readability-*,portability-*,modernize-*,clang-analyzer-cplusplus-*,clang-analyzer-*,cppcoreguidelines-* > clang-tidy-report.txt

cppcheck --version
cppcheck -iclang-format-report.txt -iclang-tidy-report.txt --enable=all --std=c++11 --language=c++ --output-file=cppcheck-report.txt ./files/*

flawfinder --version
flawfinder --columns --context --singleline ./files/ > flawfinder-report.txt

clang-format --version
./run-clang-format.py --style={BasedOnStyle: Microsoft, UseTab: Always, ColumnLimit: 180, Language: Cpp} ./files/* > clang-format-report.txt

#PAYLOAD_TIDY=`cat clang-tidy-report.txt`
PAYLOAD_CPPCHECK=`cat cppcheck-report.txt`
PAYLOAD_FLAWFINDER=`cat flawfinder-report.txt`
PAYLOAD_FORMAT=`cat clang-format-report.txt`
COMMENTS_URL=$(cat $GITHUB_EVENT_PATH | jq -r .pull_request.comments_url)
  
echo $COMMENTS_URL
#echo "Clang-tidy errors:"
#echo $PAYLOAD_TIDY
echo "Cppcheck errors:"
echo $PAYLOAD_CPPCHECK
echo "Flawfinder errors:"
echo $PAYLOAD_FLAWFINDER
echo "Clang-format errors:"
echo $PAYLOAD_FORMAT

#OUTPUT=$'**CLANG-TIDY WARNINGS**:\n'
#OUTPUT+=$'\n```\n'
#OUTPUT+="$PAYLOAD_TIDY"
#OUTPUT+=$'\n```\n'

OUTPUT=$'\n\n**CPPCHECK WARNINGS**:\n'
OUTPUT+=$'\n```\n'
OUTPUT+="$PAYLOAD_CPPCHECK"
OUTPUT+=$'\n```\n' 

OUTPUT+=$'\n\n**FLAWFINDER WARNINGS**:\n'
OUTPUT+=$'\n```\n'
OUTPUT+="$PAYLOAD_FLAWFINDER"
OUTPUT+=$'\n```\n' 

OUTPUT+=$'\n\n**CLANG-FORMAT WARNINGS**:\n'
OUTPUT+=$'\n```\n'
OUTPUT+="$PAYLOAD_FORMAT"
OUTPUT+=$'\n```\n' 

PAYLOAD=$(echo '{}' | jq --arg body "$OUTPUT" '.body = $body')

curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "Content-Type: application/vnd.github.VERSION.text+json" --data "$PAYLOAD" "$COMMENTS_URL"
