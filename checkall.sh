#!/bin/bash

# Let's check if we have a token properly set
if [[ -z "$GITHUB_TOKEN" ]]; then
	echo "The GITHUB_TOKEN is required."
	exit 1
fi


# Some prerequisites
curl -JLO https://raw.githubusercontent.com/Sarcasm/run-clang-format/master/run-clang-format.py
chmod +x ./run-clang-format.py
ERRORED=false

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

# cppcheck
cppcheck --version
cppcheck -iclang-format-report.txt -iclang-tidy-report.txt --enable=all --library=qt.cfg --std=c++17 --language=c++ --output-file=cppcheck-report.txt ./files/*.{cpp,c,hpp}

# flawfinder
flawfinder --version
flawfinder --columns --context --singleline ./files/*.{cpp,h,c,hpp} > flawfinder-report.txt

# clang-format
clang-format-12 --version
./run-clang-format.py --clang-format-executable="clang-format-12" --style="{BasedOnStyle: Microsoft, UseTab: Always, ColumnLimit: 180, NamespaceIndentation: All, Language: Cpp, SortIncludes: false}" ./files/*.{cpp,h,c,hpp} > clang-format-report.txt


# We don't want very long report, let's trunk them at 500 lines max
CPPCHECK_LINE_NUMBER=$(< cppcheck-report.txt wc -l)
if [ $CPPCHECK_LINE_NUMBER -gt 250 ]
then
head -n 250 cppcheck-report.txt > tmp.cppcheck-report.txt
PAYLOAD_CPPCHECK=`cat tmp.cppcheck-report.txt`
else
PAYLOAD_CPPCHECK=`cat cppcheck-report.txt`
fi

FLAWFINDER_LINE_NUMBER=$(< flawfinder-report.txt wc -l)
if [ $FLAWFINDER_LINE_NUMBER -gt 250 ]
then
head -n 250 flawfinder-report.txt > tmp.flawfinder-report.txt
PAYLOAD_FLAWFINDER=`cat tmp.flawfinder-report.txt`
OUTPUT+=$'\n\n**OUTPUT TOO BIG - ONLY SHOWING FIRST 250 LINES**:\n'
else
PAYLOAD_FLAWFINDER=`cat flawfinder-report.txt`
fi

CFORMAT_LINE_NUMBER=$(< clang-format-report.txt wc -l)
if [ $CFORMAT_LINE_NUMBER -gt 250 ]
then
head -n 250 clang-format-report.txt > tmp.clang-format-report.txt
PAYLOAD_FORMAT=`cat tmp.clang-format-report.txt`
OUTPUT+=$'\n\n**OUTPUT TOO BIG - ONLY SHOWING FIRST 250 LINES**:\n'
else
PAYLOAD_FORMAT=`cat clang-format-report.txt`
fi

COMMENTS_URL=$(cat $GITHUB_EVENT_PATH | jq -r .pull_request.comments_url)
  
echo $COMMENTS_URL
echo "Cppcheck errors:"
echo $PAYLOAD_CPPCHECK
echo "Flawfinder errors:"
echo $PAYLOAD_FLAWFINDER
echo "Clang-format errors:"
echo $PAYLOAD_FORMAT

OUTPUT=$'\n\n**CPPCHECK WARNINGS**:\n'
if [ $CPPCHECK_LINE_NUMBER -gt 250 ]
then
OUTPUT+=$'\n\n**OUTPUT TOO LONG - ONLY SHOWING FIRST 250 LINES**:\n'
fi
OUTPUT+=$'\n```\n'
OUTPUT+="$PAYLOAD_CPPCHECK"
OUTPUT+=$'\n```\n' 

PAYLOAD=$(echo '{}' | jq --arg body "$OUTPUT" '.body = $body')
#curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "Content-Type: application/vnd.github.VERSION.text+json" --data "$PAYLOAD" "$COMMENTS_URL"

OUTPUT=$'\n\n**FLAWFINDER WARNINGS**:\n'
if [ $FLAWFINDER_LINE_NUMBER -gt 250 ]
then
OUTPUT+=$'\n\n**OUTPUT TOO LONG - ONLY SHOWING FIRST 250 LINES**:\n'
fi
OUTPUT+=$'\n```\n'
OUTPUT+="$PAYLOAD_FLAWFINDER"
OUTPUT+=$'\n```\n' 

PAYLOAD=$(echo '{}' | jq --arg body "$OUTPUT" '.body = $body')
if [ $FLAWFINDER_LINE_NUMBER -gt 27 ]
then
curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "Content-Type: application/vnd.github.VERSION.text+json" --data "$PAYLOAD" "$COMMENTS_URL"
fi
OUTPUT=$'\n\n**CLANG-FORMAT ERROR - PLEASE FIX TO BE ABLE TO MERGE**:\n'
if [ $CFORMAT_LINE_NUMBER -gt 250 ]
then
OUTPUT+=$'\n\n**OUTPUT TOO LONG - ONLY SHOWING FIRST 250 LINES**:\n'
fi
OUTPUT+=$'\n```\n'
OUTPUT+="$PAYLOAD_FORMAT"
OUTPUT+=$'\n```\n' 

PAYLOAD=$(echo '{}' | jq --arg body "$OUTPUT" '.body = $body')
if [ $CFORMAT_LINE_NUMBER -gt 8 ]
then
ERRORED=true
curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "Content-Type: application/vnd.github.VERSION.text+json" --data "$PAYLOAD" "$COMMENTS_URL"
fi

# If we have an error, we want to set an error code so the workflow is seen as failed
if [ "$ERRORED" = true ] ; then
    exit 2
fi
